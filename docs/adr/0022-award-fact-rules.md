# 0022. Rules for the award fact

Status: Accepted (2026-10-07); headline also leaves out old-regime awards, and unsuccessful awards are dropped, since [0034](0034-award-data-corrections.md). Evidence: [eda-findings.md](../eda-findings.md#awards-rules-for-fct_award_suppliers) (complete history, 172,312 notices).

## Context
"Who's buying?" and "Who's winning?" sum award values. The same award repeats across notices (UK5, UK6, UK7) and its value and date sit on different notices or only on the contract. Framework set-ups carry ceilings repeated per lot, some amounts are implausible (£100bn for travel services), dynamic-market notices list admissions rather than awards, and joint awards don't say how they are split.

## Decision
- **Intermediate model `int_awards`**: one row per award (`procurement_award_key`) across its notices. Value: award net, else contract net, else award gross, else contract gross (`value_source`). Date: earliest award date, else contract signed date, else first publication date, as a UK date (`date_source`). GBP via the HMRC rate for that month; no GBP value when there is none (4 old foreign-currency awards).
- **Flags**: `is_framework` (framework field, 3+ suppliers or "framework" in the title, not a call-off), `is_large_value` (£100m or more, var `large_award_gbp`), `is_dynamic_market` (UK14, UK15).
- **Fact `fct_award_suppliers`**: one row per distinct supplier (normalised name) on each award; dynamic-market admissions and cancelled awards left out; pending awards kept. Value split equally between suppliers (`allocated_value_gbp`); awards without a supplier get an "Unknown supplier" row.
- **Headline totals** sum `allocated_value_gbp` where `is_in_headline`: not a framework set-up, not a large value, value known. Framework set-ups and large values stay in the table for separate views.
- `dim_dates` starts in 1990: some contracts published now were signed as early as 1990.

## Consequences
- No double counting across notices or lots; supplier shares add up to the award totals (tested).
- Equal splits and the signed date standing in for the award date are approximations; both are labelled in the data.
- Rules were set on data to 2026-10-07; re-run `snowflake/eda/award_findings.sql` when the picture changes.
