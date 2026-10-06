"""Load Find a Tender releases into Snowflake.

Each run:
1. Picks the time window to fetch: from the end of the last successful run
   (minus a 15-minute overlap) up to now.
2. Fetches every page of releases updated in that window.
3. Inserts each page, unchanged, into RAW.FIND_A_TENDER_RELEASES.
4. Logs the run in RAW.FIND_A_TENDER_INGEST_RUNS. A failed run does not move
   the window forward, so the next run fetches it again.

The overlap and re-runs can load the same release twice; dbt removes duplicates.

Run locally:  uv run ingestion/load_find_a_tender.py
Uses the Snowflake connection named in SNOWFLAKE_CONNECTION_NAME (default "tender").
The connection sets the database and warehouse, so the same code runs against any
environment; table names below are relative to that database.
"""

import json
import logging
import os
from collections.abc import Iterator
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta
from typing import Any

import requests
from requests.adapters import HTTPAdapter
from snowflake.snowpark import Session
from urllib3.util.retry import Retry

API_URL = "https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages"
API_DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"  # no time zone; we send UTC

RELEASES_TABLE = "RAW.FIND_A_TENDER_RELEASES"
RUNS_TABLE = "RAW.FIND_A_TENDER_INGEST_RUNS"

OVERLAP = timedelta(minutes=15)
FIRST_RUN_LOOKBACK = timedelta(hours=3)

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
    check_connection(session)
    run_id = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    window = next_window(session)
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
        log_run(session, run_id, window, stats, status="failed", error=str(error))
        raise
    else:
        log_run(session, run_id, window, stats, status="success")

    return f"Run {run_id}: {stats.releases} releases in {stats.pages} pages"


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


def fetch_pages(window: Window) -> Iterator[Page]:
    """Yield each page of releases in the window, following links.next."""
    http = http_session()
    url: str | None = API_URL
    params: dict[str, str | int] | None = {
        "updatedFrom": window.start.strftime(API_DATE_FORMAT),
        "updatedTo": window.end.strftime(API_DATE_FORMAT),
        "limit": 100,
    }
    while url:
        response = http.get(url, params=params, timeout=60)
        response.raise_for_status()
        page = response.json()
        yield page

        url = page.get("links", {}).get("next")  # includes the cursor
        params = None


def http_session() -> requests.Session:
    """HTTP session that waits for Retry-After and retries on 429 and 503."""
    retry = Retry(
        total=5,
        status_forcelist=[429, 503],
        respect_retry_after_header=True,
        backoff_factor=2,
    )
    http = requests.Session()
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
    status: str,
    error: str | None = None,
) -> None:
    session.sql(
        f"INSERT INTO {RUNS_TABLE} "
        "(run_id, window_from, window_to, pages, releases, status, error_message) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        params=[
            run_id,
            to_snowflake_utc(window.start),
            to_snowflake_utc(window.end),
            stats.pages,
            stats.releases,
            status,
            error,
        ],
    ).collect()


def to_snowflake_utc(moment: datetime) -> str:
    """'2026-10-06 18:00:00' for a TIMESTAMP_NTZ column holding UTC."""
    return moment.astimezone(UTC).replace(tzinfo=None).isoformat(sep=" ", timespec="seconds")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("snowflake").setLevel(logging.WARNING)
    connection_name = os.environ.get("SNOWFLAKE_CONNECTION_NAME", "tender")
    with Session.builder.config("connection_name", connection_name).create() as session:
        print(main(session))
