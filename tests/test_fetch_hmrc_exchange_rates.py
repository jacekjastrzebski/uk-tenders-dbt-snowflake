"""Local tests for the HMRC exchange rate download: the HTTP session is a fake."""

from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import cast

import requests

import fetch_hmrc_exchange_rates as hmrc

FEBRUARY_CSV = (
    "﻿Country/Territories,Currency,Currency Code,Currency Units per £1,Start date,End date\n"
    "Eurozone,Euro,EUR,1.1832,01/02/2025,28/02/2025\n"
    "USA,Dollar,USD,1.2357,01/02/2025,28/02/2025\n"
    "Ecuador,Dollar,USD,1.2357,01/02/2025,28/02/2025\n"
)


class FakeResponse:
    def __init__(self, status_code: int, text: str = "") -> None:
        self.status_code = status_code
        self.content = text.encode("utf-8")

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise requests.HTTPError(str(self.status_code))


class FakeHttp:
    """Returns the CSV for February 2025 and 404 for any other month."""

    def get(self, url: str, timeout: int) -> FakeResponse:
        if url == hmrc.month_url(date(2025, 2, 1)):
            return FakeResponse(200, FEBRUARY_CSV)
        return FakeResponse(404)

    def as_session(self) -> requests.Session:
        return cast(requests.Session, self)


def test_months_crosses_the_year_end() -> None:
    assert list(hmrc.months(date(2025, 11, 15), date(2026, 1, 1))) == [
        date(2025, 11, 1),
        date(2025, 12, 1),
        date(2026, 1, 1),
    ]


def test_month_url_has_no_leading_zero() -> None:
    assert hmrc.month_url(date(2025, 2, 1)).endswith("monthly_csv_2025-2.csv")


def test_fetch_month_parses_rates_and_keeps_each_currency_once() -> None:
    rates = hmrc.fetch_month(FakeHttp().as_session(), date(2025, 2, 1))

    assert rates == [
        hmrc.Rate("EUR", date(2025, 2, 1), Decimal("1.1832")),
        hmrc.Rate("USD", date(2025, 2, 1), Decimal("1.2357")),
    ]


def test_fetch_month_skips_a_month_not_published_yet() -> None:
    assert hmrc.fetch_month(FakeHttp().as_session(), date(2099, 1, 1)) == []


def test_write_seed_sorts_by_currency_and_month(tmp_path: Path) -> None:
    path = tmp_path / "rates.csv"
    hmrc.write_seed(
        [
            hmrc.Rate("USD", date(2025, 2, 1), Decimal("1.2357")),
            hmrc.Rate("EUR", date(2025, 3, 1), Decimal("1.19")),
            hmrc.Rate("EUR", date(2025, 2, 1), Decimal("1.1832")),
        ],
        path,
    )

    assert path.read_text().splitlines() == [
        "currency_code,month_start,units_per_gbp",
        "EUR,2025-02-01,1.1832",
        "EUR,2025-03-01,1.19",
        "USD,2025-02-01,1.2357",
    ]
