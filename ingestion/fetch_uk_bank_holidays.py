"""Download UK bank holidays (England and Wales) into a dbt seed.

Find a Tender publishes few or no notices on bank holidays, so the working-day
alert NOTICES_NOT_ARRIVING (snowflake/dbt/01_run_dbt_task.sql) skips them.
GOV.UK lists past bank holidays and those for about the next two years; this
script writes the England and Wales ones to dbt/seeds/uk_bank_holidays.csv,
one row per day.

Run from the repo root:  uv run ingestion/fetch_uk_bank_holidays.py
Then commit the updated seed. Refresh once a year, or when the dbt test
assert_bank_holidays_ahead warns that the list is running out.
"""

import csv
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

import requests

URL = "https://www.gov.uk/bank-holidays.json"
DIVISION = "england-and-wales"  # Find a Tender covers the UK; most notices follow these days
SEED_PATH = Path("dbt/seeds/uk_bank_holidays.csv")
SEED_COLUMNS = ["holiday_date", "title"]


@dataclass(frozen=True)
class BankHoliday:
    holiday_date: date
    title: str


def parse_holidays(data: dict[str, Any]) -> list[BankHoliday]:
    """Bank holidays of DIVISION from the GOV.UK JSON."""
    return [
        BankHoliday(date.fromisoformat(event["date"]), event["title"])
        for event in data[DIVISION]["events"]
    ]


def fetch(http: requests.Session) -> list[BankHoliday]:
    response = http.get(URL, timeout=30)
    response.raise_for_status()
    return parse_holidays(response.json())


def write_seed(holidays: list[BankHoliday], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(SEED_COLUMNS)
        for holiday in sorted(holidays, key=lambda h: h.holiday_date):
            writer.writerow([holiday.holiday_date.isoformat(), holiday.title])


def main() -> None:
    with requests.Session() as http:
        holidays = fetch(http)
    write_seed(holidays, SEED_PATH)
    print(f"Wrote {len(holidays)} bank holidays to {SEED_PATH}")


if __name__ == "__main__":
    main()
