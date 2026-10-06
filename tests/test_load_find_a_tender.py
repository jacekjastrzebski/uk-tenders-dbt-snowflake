"""Local tests for the loader. No network or Snowflake: both are replaced with fakes."""

from collections.abc import Callable
from datetime import UTC, datetime, timedelta
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
    """Records SQL calls; answers the watermark query with `last_end`."""

    def __init__(self, last_end: datetime | None = None, database: str | None = '"TENDER_DB"') -> None:
        self.last_end = last_end
        self.database = database
        self.calls: list[SqlCall] = []

    def get_current_database(self) -> str | None:
        return self.database

    def get_current_warehouse(self) -> str:
        return '"TENDER_WH"'

    def sql(self, query: str, params: list[Any] | None = None) -> FakeResult:
        self.calls.append((query, params))
        rows = [{"LAST_END": self.last_end}] if query.startswith("SELECT") else []
        return FakeResult(rows)

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
    assert first_params == {"updatedFrom": "2026-10-06T09:00:00", "updatedTo": "2026-10-06T12:00:00", "limit": 100}
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
