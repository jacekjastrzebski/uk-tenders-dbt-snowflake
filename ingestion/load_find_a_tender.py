"""Load Find a Tender releases into Snowflake.

Each run:
1. Picks the time window to fetch: from the end of the last successful run
   (minus a 15-minute overlap) up to now.
2. Fetches every page of releases updated in that window.
3. Inserts each page, unchanged, into RAW.FIND_A_TENDER_RELEASES.
4. Logs the run in RAW.FIND_A_TENDER_INGEST_RUNS. A failed run does not move
   the window forward, so the next run fetches it again.

The overlap and re-runs can load the same release twice; dbt removes duplicates.

Backfill (ADR 0017) loads history one UTC day per run, from a start date up to
where the scheduled runs began. Runs are logged with run_type 'backfill'; days
already loaded are skipped, so an interrupted backfill resumes when run again.

Run locally:  uv run ingestion/load_find_a_tender.py
Backfill:     uv run ingestion/load_find_a_tender.py --backfill [YYYY-MM-DD]
              (in Snowflake: CALL RAW.BACKFILL_FIND_A_TENDER_RELEASES(), see 02_ingest_procedure.sql)
Uses the Snowflake connection named in SNOWFLAKE_CONNECTION_NAME (default "tender").
The connection sets the database and warehouse, so the same code runs against any
environment; table names below are relative to that database.
"""

import argparse
import json
import logging
import os
from collections.abc import Iterator
from dataclasses import dataclass, replace
from datetime import UTC, date, datetime, time, timedelta
from time import sleep
from typing import Any
from zoneinfo import ZoneInfo

import requests
from requests.adapters import HTTPAdapter
from snowflake.snowpark import Session
from urllib3.util.retry import Retry

API_URL = "https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages"
API_DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"  # no offset; the API reads it as UK local time
API_TIME_ZONE = ZoneInfo("Europe/London")  # ADR 0018

# The API's rate limit is not documented; the backfill hit it after ~1,200 requests
# in ~35 minutes and was asked to wait 120 seconds (Retry-After).
API_PAUSE_SECONDS = 2  # between requests
API_RETRIES = 10  # each waits Retry-After, so a run rides out ~20 minutes of 429s
USER_AGENT = "uk-tenders-dbt-snowflake (+https://github.com/jacekjastrzebski/uk-tenders-dbt-snowflake)"

RELEASES_TABLE = "RAW.FIND_A_TENDER_RELEASES"
RUNS_TABLE = "RAW.FIND_A_TENDER_INGEST_RUNS"

OVERLAP = timedelta(minutes=15)
FIRST_RUN_LOOKBACK = timedelta(hours=3)

INCREMENTAL = "incremental"
BACKFILL = "backfill"
BACKFILL_START = date(2025, 2, 24)  # Procurement Act 2023 in force (ADR 0017)
BACKFILL_DAY = timedelta(days=1)
RUN_ID_FORMAT = "%Y%m%dT%H%M%SZ"

log = logging.getLogger(__name__)

type Page = dict[str, Any]  # one API response: a release package


@dataclass(frozen=True)
class Window:
    start: datetime
    end: datetime


@dataclass(frozen=True)
class RunStats:
    pages: int = 0
    releases: int = 0


def main(session: Session) -> str:
    """Scheduled run: everything updated since the last successful run."""
    check_connection(session)
    run_id = datetime.now(UTC).strftime(RUN_ID_FORMAT)
    stats = load_window(session, run_id, next_window(session), INCREMENTAL)
    return f"Run {run_id}: {stats.releases} releases in {stats.pages} pages"


def backfill(session: Session, start: date) -> str:
    """Load each day from `start` up to the first scheduled run, skipping days already loaded."""
    check_connection(session)
    loaded_ends = backfilled_window_ends(session)
    days = [
        (day, window)
        for day, window in backfill_windows(start, backfill_stop(session))
        if window.end not in loaded_ends
    ]
    log.info("Backfill from %s: %d days to load", start, len(days))

    total = RunStats()
    for day, window in days:
        run_id = f"{datetime.now(UTC).strftime(RUN_ID_FORMAT)}-{day:%Y%m%d}"
        stats = load_window(session, run_id, window, BACKFILL)
        total = RunStats(pages=total.pages + stats.pages, releases=total.releases + stats.releases)

    return f"Backfill: {total.releases} releases in {total.pages} pages over {len(days)} days"


def load_window(session: Session, run_id: str, window: Window, run_type: str) -> RunStats:
    """Fetch and save every page in the window, then log the run; a failure is logged and re-raised."""
    stats = RunStats()
    log.info("Run %s: fetching %s to %s UTC", run_id, window.start, window.end)

    try:
        for page in fetch_pages(window):
            save_page(session, run_id, stats.pages, page)
            stats = replace(
                stats,
                pages=stats.pages + 1,
                releases=stats.releases + len(page["releases"]),
            )
            log.info("Page %d: %d releases", stats.pages, len(page["releases"]))
    except Exception as error:
        log_run(session, run_id, window, stats, run_type, status="failed", error=str(error))
        raise
    else:
        log_run(session, run_id, window, stats, run_type, status="success")

    return stats


def check_connection(session: Session) -> None:
    """Fail early if the connection does not set a database and warehouse."""
    missing = [
        name
        for name, value in [
            ("database", session.get_current_database()),
            ("warehouse", session.get_current_warehouse()),
        ]
        if not value
    ]
    if missing:
        raise ValueError(f"Snowflake connection must set: {', '.join(missing)}")


def next_window(session: Session) -> Window:
    """From the end of the last successful run (minus the overlap) up to now."""
    now = datetime.now(UTC).replace(microsecond=0)
    last_end = session.sql(
        f"SELECT MAX(window_to) AS last_end FROM {RUNS_TABLE} WHERE status = 'success'"
    ).collect()[0]["LAST_END"]

    if last_end is None:
        return Window(start=now - FIRST_RUN_LOOKBACK, end=now)
    return Window(start=last_end.replace(tzinfo=UTC) - OVERLAP, end=now)


def backfill_stop(session: Session) -> datetime:
    """Where the first scheduled run started, so backfill and scheduled windows join up.

    Refuses to run before any scheduled run has succeeded: the scheduled load
    starts from the newest successful run of either kind, so it would then
    resume from wherever the backfill had got to and fetch months in one run.
    """
    first_start: datetime | None = session.sql(
        f"SELECT MIN(window_from) AS first_start FROM {RUNS_TABLE} "
        f"WHERE status = 'success' AND COALESCE(run_type, '{INCREMENTAL}') = '{INCREMENTAL}'"
    ).collect()[0]["FIRST_START"]

    if first_start is None:
        raise RuntimeError("No successful scheduled run yet: run the scheduled load once before backfilling")
    return first_start.replace(tzinfo=UTC)


def backfilled_window_ends(session: Session) -> set[datetime]:
    """End of every successful backfill window; a day whose window ends here is already loaded."""
    rows = session.sql(
        f"SELECT window_to FROM {RUNS_TABLE} WHERE status = 'success' AND run_type = '{BACKFILL}'"
    ).collect()
    return {row["WINDOW_TO"].replace(tzinfo=UTC) for row in rows}


def backfill_windows(start: date, stop: datetime) -> list[tuple[date, Window]]:
    """One window per UTC day from `start` until `stop`, each starting OVERLAP early."""
    windows = []
    day = start
    while (day_start := datetime.combine(day, time(), tzinfo=UTC)) < stop:
        windows.append((day, Window(start=day_start - OVERLAP, end=min(day_start + BACKFILL_DAY, stop))))
        day += BACKFILL_DAY
    return windows


def fetch_pages(window: Window) -> Iterator[Page]:
    """Yield each page of releases in the window, following links.next; pauses after each request."""
    http = http_session()
    url: str | None = API_URL
    updated_from, updated_to = api_dates(window)
    params: dict[str, str | int] | None = {
        "updatedFrom": updated_from,
        "updatedTo": updated_to,
        "limit": 100,
    }
    while url:
        response = http.get(url, params=params, timeout=60)
        response.raise_for_status()
        page = response.json()
        sleep(API_PAUSE_SECONDS)
        yield page

        url = page.get("links", {}).get("next")  # includes the cursor
        params = None


def api_dates(window: Window) -> tuple[str, str]:
    """The window as UK local times, which the API expects.

    When the clocks go back, 01:00-02:00 happens twice and the API may read a
    time in that hour as the second one. A window that spans the change
    therefore starts an hour earlier, so that hour is never skipped.
    """
    start = window.start.astimezone(API_TIME_ZONE)
    end = window.end.astimezone(API_TIME_ZONE)
    offset_change = (start.utcoffset() or timedelta(0)) - (end.utcoffset() or timedelta(0))
    clocks_went_back = max(offset_change, timedelta(0))
    return (start - clocks_went_back).strftime(API_DATE_FORMAT), end.strftime(API_DATE_FORMAT)


def http_session() -> requests.Session:
    """HTTP session that waits for Retry-After on 429 and 503, and backs off on other server errors."""
    retry = Retry(
        total=API_RETRIES,
        status_forcelist=[429, 500, 502, 503, 504],
        respect_retry_after_header=True,
        backoff_factor=2,
    )
    http = requests.Session()
    http.headers["User-Agent"] = USER_AGENT
    http.mount("https://", HTTPAdapter(max_retries=retry))
    return http


def save_page(session: Session, run_id: str, page_number: int, page: Page) -> None:
    session.sql(
        f"INSERT INTO {RELEASES_TABLE} (run_id, page_number, payload) "
        "SELECT ?, ?, PARSE_JSON(?)",
        params=[run_id, page_number, json.dumps(page)],
    ).collect()


def log_run(
    session: Session,
    run_id: str,
    window: Window,
    stats: RunStats,
    run_type: str,
    status: str,
    error: str | None = None,
) -> None:
    columns = ["run_id", "window_from", "window_to", "pages", "releases", "status", "error_message"]
    values: list[Any] = [
        run_id,
        to_snowflake_utc(window.start),
        to_snowflake_utc(window.end),
        stats.pages,
        stats.releases,
        status,
        error,
    ]
    # Scheduled runs leave run_type to its column default, so the deployed loader
    # keeps working whether or not the column has been added yet.
    if run_type != INCREMENTAL:
        columns.append("run_type")
        values.append(run_type)

    session.sql(
        f"INSERT INTO {RUNS_TABLE} ({', '.join(columns)}) VALUES ({', '.join('?' for _ in values)})",
        params=values,
    ).collect()


def to_snowflake_utc(moment: datetime) -> str:
    """'2026-10-06 18:00:00' for a TIMESTAMP_NTZ column holding UTC."""
    return moment.astimezone(UTC).replace(tzinfo=None).isoformat(sep=" ", timespec="seconds")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load Find a Tender releases into Snowflake.")
    parser.add_argument(
        "--backfill",
        nargs="?",
        const=BACKFILL_START,
        type=date.fromisoformat,
        metavar="YYYY-MM-DD",
        help=f"load history one day per run, from this date (default {BACKFILL_START})",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("snowflake").setLevel(logging.WARNING)
    connection_name = os.environ.get("SNOWFLAKE_CONNECTION_NAME", "tender")
    with Session.builder.config("connection_name", connection_name).create() as session:
        print(backfill(session, args.backfill) if args.backfill else main(session))
