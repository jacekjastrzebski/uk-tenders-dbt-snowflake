# 0018. Convert amounts to GBP with HMRC monthly rates

Status: Accepted (2026-10-07). Numbered 0018 because 0017 is on the backfill branch.

## Context
Most notice values are in GBP, but some are not (2 EUR awards and 1 USD contract in the first days of data). Summing across currencies gives wrong totals. Options were filtering to GBP, a Snowflake Marketplace FX dataset, or official HMRC rates. Snowflake's own FX listing is paid after a 60-day trial; the free "Federal Exchange Rates" listing is not available in this account's Azure region.

## Decision
- Convert every amount to GBP in the marts: `amount / units_per_gbp`.
- Rates: HMRC monthly exchange rates (currency units per £1), downloaded by `ingestion/fetch_hmrc_exchange_rates.py` into the seed `dbt/seeds/hmrc_exchange_rates.csv` (from January 2025).
- Rate date: the month of the value's own date: `awarded_at` for awards, `signed_at` for contracts, else the notice's `published_at`.

## Consequences
- Official UK government source, fully in the repo, no third-party dependency.
- Monthly, not daily, rates: accurate enough for market totals.
- The seed must be refreshed (run the script, commit the CSV); a mart test fails when an amount has no rate for its currency and month.
- Can switch to a Marketplace dataset later if one becomes available in the region.
