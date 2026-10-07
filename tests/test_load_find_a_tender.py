"""Local tests for the loader. No network or Snowflake: both are replaced with fakes."""

from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any, cast

import pytest
from snowflake.snowpark import Session

import load_find_a_tender as loader
from load_find_a_tender import Page

LAST_END = datetime(2026, 10, 6, 12, 0, 0)  # naive UTC, as Snowflake returns TIMESTAMP_NTZ

type SqlCall = tuple[str, list[Any] | None]


class FakeResult:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self.rows = rows

    def collect(self) -> list[dict[str, Any]]:
        return self.rows


class FakeSession:
    """Records SQL calls; answers the run-log queries from the given timestamps (naive UTC)."""

    def __init__(
        self,
        last_end: datetime | None = None,
        database: str | None = '"TENDER_DB"',
        first_scheduled_start: datetime | None = None,
        backfilled_ends: list[datetime] | None = None,
    ) -> None:
        self.last_end = last_end
        self.database = database
        self.first_scheduled_start = first_scheduled_start
        self.backfilled_ends = backfilled_ends or []
        self.calls: list[SqlCall] = []

    def get_current_database(self) -> str | None:
        return self.database

    def get_current_warehouse(self) -> str:
        return '"TENDER_WH"'

    def sql(self, query: str, params: list[Any] | None = None) -> FakeResult:
        self.calls.append((query, params))
        if "MIN(window_from)" in query:
            return FakeResult([{"FIRST_START": self.first_scheduled_start}])
        if "SELECT window_to" in query:
            return FakeResult([{"WINDOW_TO": end} for end in self.backfilled_ends])
        if query.startswith("SELECT"):
            return FakeResult([{"LAST_END": self.last_end}])
        return FakeResult([])

    def inserts_into(self, table: str) -> list[list[Any]]:
        return [params or [] for query, params in self.calls if f"INSERT INTO {table}" in query]

    def as_session(self) -> Session:
        return cast(Session, self)


class FakeResponse:
    def __init__(self, body: Page | Exception) -> None:
        self.body = body

    def raise_for_status(self) -> None:
        if isinstance(self.body, Exception):
            raise self.body

    def json(self) -> Page | Exception:
        return self.body


class FakeHttp:
    """Returns the given pages in order and records each request."""

    def __init__(self, pages: list[Page | Exception]) -> None:
        self.pages = list(pages)
        self.requests: list[tuple[str, dict[str, Any] | None]] = []

    def get(self, url: str, params: dict[str, Any] | None = None, timeout: int | None = None) -> FakeResponse:
        self.requests.append((url, params))
        return FakeResponse(self.pages.pop(0))


def page(release_count: int, next_url: str | None = None) -> Page:
    links = {"next": next_url} if next_url else {}
    return {"releases": [{"id": str(i)} for i in range(release_count)], "links": links}


@pytest.fixture
def fake_http(monkeypatch: pytest.MonkeyPatch) -> Callable[[list[Page | Exception]], FakeHttp]:
    def install(pages: list[Page | Exception]) -> FakeHttp:
        http = FakeHttp(pages)
        monkeypatch.setattr(loader, "http_session", lambda: http)
        return http

    return install


def test_first_run_looks_back_three_hours() -> None:
    window = loader.next_window(FakeSession(last_end=None).as_session())

    assert window.end - window.start == loader.FIRST_RUN_LOOKBACK


def test_next_run_starts_before_last_end_by_the_overlap() -> None:
    window = loader.next_window(FakeSession(last_end=LAST_END).as_session())

    assert window.start == LAST_END.replace(tzinfo=UTC) - timedelta(minutes=15)


def test_fetch_pages_follows_next_links(fake_http: Callable[[list[Page | Exception]], FakeHttp]) -> None:
    http = fake_http([page(100, next_url="https://api/next"), page(3)])
    window = loader.Window(
        start=datetime(2026, 10, 6, 9, tzinfo=UTC),
        end=datetime(2026, 10, 6, 12, tzinfo=UTC),
    )

    pages = list(loader.fetch_pages(window))

    assert [len(p["releases"]) for p in pages] == [100, 3]
    _, first_params = http.requests[0]
    # 09:00-12:00 UTC is 10:00-13:00 UK time (BST)
    assert first_params == {"updatedFrom": "2026-10-06T10:00:00", "updatedTo": "2026-10-06T13:00:00", "limit": 100}
    assert http.requests[1] == ("https://api/next", None)  # cursor is already in the next URL


def test_successful_run_saves_pages_and_logs_success(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    fake_http([page(100, next_url="https://api/next"), page(3)])
    session = FakeSession(last_end=LAST_END)

    result = loader.main(session.as_session())

    assert result.endswith("103 releases in 2 pages")
    assert len(session.inserts_into(loader.RELEASES_TABLE)) == 2
    [run] = session.inserts_into(loader.RUNS_TABLE)
    assert run[3:6] == [2, 103, "success"]  # pages, releases, status


def test_failed_run_logs_failure_and_raises(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    fake_http([page(100, next_url="https://api/next"), RuntimeError("API down")])
    session = FakeSession(last_end=LAST_END)

    with pytest.raises(RuntimeError, match="API down"):
        loader.main(session.as_session())

    [run] = session.inserts_into(loader.RUNS_TABLE)
    assert run[3:7] == [1, 100, "failed", "API down"]  # pages, releases, status, error


def test_connection_without_database_is_rejected() -> None:
    with pytest.raises(ValueError, match="must set: database"):
        loader.main(FakeSession(database=None).as_session())


def test_timestamps_are_written_as_naive_utc() -> None:
    same_moment_in_local_time = datetime(2026, 10, 6, 19, 30, tzinfo=UTC).astimezone()

    assert loader.to_snowflake_utc(same_moment_in_local_time) == "2026-10-06 19:30:00"


def utc(year: int, month: int, day: int, hour: int, minute: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=UTC)


def test_api_dates_are_uk_local_time_in_winter() -> None:
    window = loader.Window(start=utc(2025, 12, 2, 10), end=utc(2025, 12, 2, 11))

    assert loader.api_dates(window) == ("2025-12-02T10:00:00", "2025-12-02T11:00:00")


def test_api_dates_start_an_hour_early_when_the_clocks_go_back() -> None:
    # Clocks went back at 01:00 UTC on 26 October 2025: 01:00-02:00 UK time happened twice
    window = loader.Window(start=utc(2025, 10, 26, 0, 30), end=utc(2025, 10, 26, 3))

    assert loader.api_dates(window) == ("2025-10-26T00:30:00", "2025-10-26T03:00:00")


def test_api_dates_are_not_shortened_when_the_clocks_go_forward() -> None:
    # Clocks went forward at 01:00 UTC on 30 March 2025: 01:00 GMT became 02:00 BST
    window = loader.Window(start=utc(2025, 3, 30, 0, 30), end=utc(2025, 3, 30, 3))

    assert loader.api_dates(window) == ("2025-03-30T00:30:00", "2025-03-30T04:00:00")


# Backfill

FIRST_SCHEDULED_START = datetime(2025, 3, 3, 9, 0, 0)  # naive UTC, as Snowflake returns it


def test_backfill_windows_cover_each_day_with_the_overlap() -> None:
    stop = datetime(2025, 3, 3, 9, tzinfo=UTC)

    windows = loader.backfill_windows(date(2025, 3, 1), stop)

    assert [day for day, _ in windows] == [date(2025, 3, 1), date(2025, 3, 2), date(2025, 3, 3)]
    _, first = windows[0]
    assert first.start == datetime(2025, 2, 28, 23, 45, tzinfo=UTC)
    assert first.end == datetime(2025, 3, 2, tzinfo=UTC)
    _, last = windows[-1]
    assert last.end == stop  # the last day stops where the scheduled runs began


def test_backfill_windows_are_empty_when_start_is_after_stop() -> None:
    assert loader.backfill_windows(date(2025, 3, 4), datetime(2025, 3, 3, tzinfo=UTC)) == []


def test_backfill_stops_where_scheduled_runs_began() -> None:
    session = FakeSession(first_scheduled_start=FIRST_SCHEDULED_START)

    assert loader.backfill_stop(session.as_session()) == FIRST_SCHEDULED_START.replace(tzinfo=UTC)


def test_backfill_refuses_to_run_before_any_scheduled_run(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    http = fake_http([])
    session = FakeSession(first_scheduled_start=None)

    with pytest.raises(RuntimeError, match="No successful scheduled run yet"):
        loader.backfill(session.as_session(), date(2025, 3, 1))

    assert http.requests == []
    assert session.inserts_into(loader.RUNS_TABLE) == []


def test_backfill_loads_each_day_and_logs_it_as_backfill(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    http = fake_http([page(5), page(7), page(1)])
    session = FakeSession(first_scheduled_start=FIRST_SCHEDULED_START)

    result = loader.backfill(session.as_session(), date(2025, 3, 1))

    assert result == "Backfill: 13 releases in 3 pages over 3 days"
    _, first_params = http.requests[0]
    assert first_params is not None
    assert first_params["updatedFrom"] == "2025-02-28T23:45:00"
    runs = session.inserts_into(loader.RUNS_TABLE)
    assert [run[5] for run in runs] == ["success"] * 3
    assert [run[-1] for run in runs] == ["backfill"] * 3
    assert runs[0][0].endswith("-20250301")  # run ID names the day


def test_backfill_skips_days_already_loaded(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    http = fake_http([page(1)])
    session = FakeSession(
        first_scheduled_start=FIRST_SCHEDULED_START,
        backfilled_ends=[datetime(2025, 3, 2), datetime(2025, 3, 3)],  # 1 and 2 March done
    )

    loader.backfill(session.as_session(), date(2025, 3, 1))

    [(_, params)] = http.requests
    assert params is not None
    assert params["updatedFrom"] == "2025-03-02T23:45:00"  # only 3 March is fetched


def test_backfill_stops_at_the_first_failed_day(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    http = fake_http([page(5), RuntimeError("API down"), page(1)])
    session = FakeSession(first_scheduled_start=FIRST_SCHEDULED_START)

    with pytest.raises(RuntimeError, match="API down"):
        loader.backfill(session.as_session(), date(2025, 3, 1))

    assert len(http.requests) == 2  # 3 March is never fetched
    runs = session.inserts_into(loader.RUNS_TABLE)
    assert [run[5] for run in runs] == ["success", "failed"]


def test_scheduled_run_leaves_run_type_to_the_column_default(
    fake_http: Callable[[list[Page | Exception]], FakeHttp],
) -> None:
    fake_http([page(1)])
    session = FakeSession(last_end=LAST_END)

    loader.main(session.as_session())

    [(query, _)] = [call for call in session.calls if f"INSERT INTO {loader.RUNS_TABLE}" in call[0]]
    assert "run_type" not in query
