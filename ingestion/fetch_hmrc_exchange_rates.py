"""Download HMRC monthly exchange rates into a dbt seed.

HMRC publishes one CSV per month with the number of currency units per £1.
This script fetches every month from FIRST_MONTH up to next month (HMRC
publishes a month's rates shortly before it starts) and writes them to
dbt/seeds/hmrc_exchange_rates.csv, one row per currency and month.
A month that isn't published yet is skipped.

Convert an amount to GBP with: amount / units_per_gbp.

Run from the repo root:  uv run ingestion/fetch_hmrc_exchange_rates.py
Then commit the updated seed. Refresh monthly, or when a mart test reports
a currency or month without a rate.
"""

import csv
import io
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from pathlib import Path

import requests

URL_TEMPLATE = (
    "https://www.trade-tariff.service.gov.uk/api/v2/exchange_rates/files/"
    "monthly_csv_{year}-{month}.csv"
)
FIRST_MONTH = date(2025, 1, 1)  # covers notices from the Procurement Act start (Feb 2025)
SEED_PATH = Path("dbt/seeds/hmrc_exchange_rates.csv")
SEED_COLUMNS = ["currency_code", "month_start", "units_per_gbp"]


@dataclass(frozen=True)
class Rate:
    currency_code: str
    month_start: date
    units_per_gbp: Decimal


def months(first: date, last: date) -> Iterator[date]:
    """First day of every month from `first` to `last`, inclusive."""
    month = first.replace(day=1)
    while month <= last:
        yield month
        month = month.replace(year=month.year + 1, month=1) if month.month == 12 else month.replace(month=month.month + 1)


def next_month(today: date) -> date:
    return today.replace(year=today.year + 1, month=1, day=1) if today.month == 12 else today.replace(month=today.month + 1, day=1)


def month_url(month: date) -> str:
    return URL_TEMPLATE.format(year=month.year, month=month.month)  # HMRC uses 2025-2, not 2025-02


def parse_rates(text: str, month: date) -> list[Rate]:
    """Rates from one HMRC CSV; a currency listed for several countries is kept once."""
    rates: dict[str, Rate] = {}
    for row in csv.DictReader(io.StringIO(text)):
        code = row["Currency Code"].strip()
        if code and code not in rates:
            rates[code] = Rate(code, month, Decimal(row["Currency Units per £1"].strip()))
    return list(rates.values())


def fetch_month(http: requests.Session, month: date) -> list[Rate]:
    """Rates for one month; empty if HMRC hasn't published it yet."""
    response = http.get(month_url(month), timeout=30)
    if response.status_code == 404:
        return []
    response.raise_for_status()
    return parse_rates(response.content.decode("utf-8-sig"), month)


def write_seed(rates: list[Rate], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(SEED_COLUMNS)
        for rate in sorted(rates, key=lambda r: (r.currency_code, r.month_start)):
            writer.writerow([rate.currency_code, rate.month_start.isoformat(), rate.units_per_gbp])


def main() -> None:
    last = next_month(datetime.now(UTC).date())
    with requests.Session() as http:
        rates = [rate for month in months(FIRST_MONTH, last) for rate in fetch_month(http, month)]
    write_seed(rates, SEED_PATH)
    print(f"Wrote {len(rates)} rates to {SEED_PATH}")


if __name__ == "__main__":
    main()
