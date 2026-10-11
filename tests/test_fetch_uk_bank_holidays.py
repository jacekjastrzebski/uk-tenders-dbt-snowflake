"""Local tests for the bank holidays download: the HTTP session is a fake."""

from datetime import date
from pathlib import Path
from typing import Any, cast

import pytest
import requests

import fetch_uk_bank_holidays as holidays

GOV_UK_JSON: dict[str, Any] = {
    "england-and-wales": {
        "division": "england-and-wales",
        "events": [
            {"title": "Boxing Day", "date": "2025-12-26", "notes": "", "bunting": True},
            {"title": "Christmas Day", "date": "2025-12-25", "notes": "", "bunting": True},
        ],
    },
    "scotland": {
        "division": "scotland",
        "events": [{"title": "St Andrew’s Day", "date": "2025-12-01", "notes": "", "bunting": True}],
    },
}


class FakeResponse:
    def __init__(self, status_code: int, data: dict[str, Any] | None = None) -> None:
        self.status_code = status_code
        self.data = data or {}

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise requests.HTTPError(str(self.status_code))

    def json(self) -> dict[str, Any]:
        return self.data


class FakeHttp:
    """Answers the GOV.UK URL with a fixed response."""

    def __init__(self, response: FakeResponse) -> None:
        self.response = response

    def get(self, url: str, timeout: int) -> FakeResponse:
        assert url == holidays.URL
        return self.response

    def as_session(self) -> requests.Session:
        return cast(requests.Session, self)


def test_fetch_keeps_only_england_and_wales() -> None:
    result = holidays.fetch(FakeHttp(FakeResponse(200, GOV_UK_JSON)).as_session())

    assert result == [
        holidays.BankHoliday(date(2025, 12, 26), "Boxing Day"),
        holidays.BankHoliday(date(2025, 12, 25), "Christmas Day"),
    ]


def test_fetch_raises_on_an_http_error() -> None:
    with pytest.raises(requests.HTTPError):
        holidays.fetch(FakeHttp(FakeResponse(503)).as_session())


def test_write_seed_sorts_by_date(tmp_path: Path) -> None:
    path = tmp_path / "holidays.csv"
    holidays.write_seed(
        [
            holidays.BankHoliday(date(2025, 12, 26), "Boxing Day"),
            holidays.BankHoliday(date(2025, 12, 25), "Christmas Day"),
        ],
        path,
    )

    assert path.read_text().splitlines() == [
        "holiday_date,title",
        "2025-12-25,Christmas Day",
        "2025-12-26,Boxing Day",
    ]
