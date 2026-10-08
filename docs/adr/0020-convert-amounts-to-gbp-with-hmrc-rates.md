# 0020. Convert amounts to GBP with HMRC monthly rates

Status: Accepted (2026-10-07). The rate month and the seed check corrected by [0034](0034-award-data-corrections.md): the latest rate on or before the award month, and a warning test.

## Context
Most notice values are in GBP, but some are not (2 EUR awards and 1 USD contract in the first days of data). Summing across currencies gives wrong totals. Options were filtering to GBP, a Snowflake Marketplace FX dataset, or official HMRC rates. Snowflake's own FX listing is paid after a 60-day trial; the free "Federal Exchange Rates" listing is not available in this account's Azure region.

## Decision
- Convert every amount to GBP in the marts: `amount / units_per_gbp`.
- Rates: HMRC monthly exchange rates (currency units per £1), downloaded by `ingestion/fetch_hmrc_exchange_rates.py` into the seed `dbt/seeds/hmrc_exchange_rates.csv` (from January 2025).
- Rate date: the month of the award's date (`int_awards.award_date`: award date, else contract signed date, else first publication). Since 0034, the latest rate on or before that month.

## Consequences
- Official UK government source, fully in the repo, no third-party dependency.
- Monthly, not daily, rates: accurate enough for market totals.
- The seed must be refreshed monthly (run the script, commit the CSV); since 0034 the test `assert_fx_rates_recent` warns when it has fallen more than 2 months behind.
- Can switch to a Marketplace dataset later if one becomes available in the region.
