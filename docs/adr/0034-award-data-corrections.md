# 0034. Award data corrections: old regime out of the headline, rates, lots, ties

Status: Accepted (2026-10-08). Changes [0020](0020-convert-amounts-to-gbp-with-hmrc-rates.md) (which rate), [0021](0021-keep-supplier-names.md) (lot rule), [0022](0022-award-fact-rules.md) (headline, unsuccessful awards) and [0027](0027-one-name-per-buyer-id.md) (ties).

## Context
A review of the data in October 2026 found numbers that were wrong or misleading:
- **Old regime in the headline.** Awards under the rules before the Procurement Act were in the headline totals (12,881 awards, £30.2bn of £73.3bn for October 2025 to September 2026), although the report says they are left out.
- **"Unsuccessful" awards.** 1,743 lots that nobody won showed up as "Unknown supplier" rows.
- **Award to contract.** Without an award notice (UK6), the award date falls back to the contract notice's own date, so 2,343 of 6,236 tenders counted 0 days. The median showed 23 days instead of about 47.
- **Exchange rates.** The rates seed ends with October 2026. From November, a non-GBP award would get no £ value, and no test would say so. ADR 0020 also described the rate month wrongly (it is the award date's month).
- **Lot rule.** A single trailing letter or number was removed as a lot, which merged "Housing 21" into "Housing" and "NHS 24" into "NHS".
- **Ties.** `MODE()` and `ROW_NUMBER()` broke ties at random, so a buyer's name could change between runs. An award's contract value and currency could come from different contract notices.

## Decision
- `fct_award_suppliers` gets `is_old_regime`. `is_in_headline` also requires `NOT is_old_regime`. The rows stay, flagged.
- Awards with status `unsuccessful` are dropped from `fct_award_suppliers`, like cancelled ones.
- `days_award_to_contract` is worked out only when there is an award notice. `award_published_date` keeps its fallback for dating the award.
- **Exchange rates:**
  - `int_awards` uses the latest HMRC rate on or before the award month (`ASOF JOIN`), and records it in `rate_month`.
  - A warning test, `assert_fx_rates_recent`, flags a rate more than 2 months older than its award.
  - Refresh the seed monthly.
- **Lot rule:** only an explicit "- Lot …", or a trailing run of **two or more** single letters and 1–2 digit numbers, is removed.
- **Deterministic choices:**
  - a buyer ID's main name is the one it uses most, and a tie goes to the name used most recently
  - "latest notice" ties go to the higher notice ID
  - an award's contract value and currency come from one contract entry: the latest with a value
- **New tests:**
  - `not_null` on `buyer_key` in both facts
  - `accepted_values` on `value_source` and `date_source`

## Consequences
- **Headline for October 2025 to September 2026:** 42,570 awards and £43.0bn, down from 55,450 and £73.3bn.
- **Unknown supplier rows:** 1,439, down from 3,182.
- **Median days from award to contract:** 47 over 4,877 tenders, up from 23 over 7,657.
- **Buyers:** 4,176 (was 4,174). **Suppliers:** 63,354 (was 63,352). The changes are names ending in one letter or number, and buyer IDs whose name tie now resolves the same way every run.
- **Values:** 40 award values and 2 currencies changed, because value and currency now come from one contract entry.
- **Exchange rates:** a late seed refresh no longer drops £ values. The amounts use a slightly older rate until the refresh, and the warning says so.
- **Real names that end in two short tokens** would still be cut, e.g. "Studio 2 B". None were found.
