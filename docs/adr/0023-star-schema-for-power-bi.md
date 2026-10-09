# 0023. Marts as a star schema for Power BI

Status: Accepted (2026-10-07). Replaces the research draft (ADR 0013 on `research/gold-powerbi`). Market share sums to 100% since 2026-10-08, when `Market Share` started dividing by named suppliers only ([powerbi.md](../powerbi.md#pages)).

## Context
The dashboard answers four questions, used as page headers: **What's open to bid?**, **Who's buying?**, **Who's winning?**, **How long to award?** (README). They are counted at two grains: a procurement (open tenders, durations) and a supplier on an award (value bought and won). Staging keeps one row per notice, so the same award and its value repeat across a procurement's notices. Power BI performs best, and its DAX stays simplest, with a star schema: facts joined directly to dimensions.

## Decision
- **Star schema**, not snowflake: every dimension joins the facts directly; chains such as CPV code → division → market are flattened into one dimension.
- Two facts:
  - `fct_procurements`: one row per Procurement Act tender (`ocid` with a UK4 notice): closing date, tender, award and contract publication dates, durations, cancelled flag. Whether a tender is open is worked out in Power BI from today's date. Answers *What's open to bid?* and *How long to award?*
  - `fct_award_suppliers`: one row per supplier on an award, deduplicated across notices (`procurement_award_key`, latest notice wins); value in GBP, split equally between joint suppliers so totals add up. Answers *Who's buying?* and *Who's winning?*
- Dimensions: `dim_dates` (generated calendar, UK financial year), `dim_buyers`, `dim_suppliers` (grouped by normalised name plus a seed for exceptions), `dim_cpv_divisions` (sector and the digital-and-data market flag: CPV 48, 72).
- Amounts converted to GBP ([0020](0020-convert-amounts-to-gbp-with-hmrc-rates.md)); marts materialised as tables with `+grants` for a read-only reporting role.
- Dropped from the research draft: `fct_notices` and `dim_notice_types`; no header needs them.

## Consequences
- No double counting of awards; supplier market share sums to 100%.
- A fact has several dates (e.g. tender, award, contract): one active relationship to `dim_dates` in Power BI, the others used through `USERELATIONSHIP`.
- Equal split of joint awards is a simplification; framework awards carry a ceiling, not spend.
- Headline numbers need history: thin until the backfill lands.
