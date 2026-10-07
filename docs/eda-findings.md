# EDA findings: raw Find a Tender data

What the first loaded data looks like, and what it means for the dbt models. Based on 151 notices published 6–7 October 2026; re-run the queries as more data arrives. Queries: `snowflake/eda/explore_releases.sql`.

## Summary

| Finding | Numbers | Consequence for dbt |
|---|---|---|
| Overlapping load windows create duplicates | 178 rows, 151 distinct notices | Deduplicate on notice `id`, latest load wins |
| `tag` is coarse | `award,contract` covers UK5, UK6, UK7 and UK15 | Classify notices by `noticeType`, not `tag` |
| Values sit in different places | contract value 66, tender value 34, award value 20 notices | Keep all three; marts pick per notice type |
| CPV codes mostly on items | items 54, `tender.classification` 22 notices | Coalesce item and tender CPV |
| Little history | about 1 day of notices | Dashboards need a historical backfill |

## Tags vs notice types

`tag` follows the OCDS [release tag codelist](https://standard.open-contracting.org/latest/en/schema/codelists/#release-tag): it says which sections a release fills (planning, tender, award, contract) and whether it updates an earlier one (`*Update`, `*Amendment`, `*Cancellation`). It does not say which Procurement Act notice it is. That is in `documents[].noticeType` (UK1–UK17, see [procurement primer](procurement-primer.md)).

| Tags | Notice type | Notices |
|---|---|---|
| award, contract | UK7 contract details | 57 |
| tender | UK4 tender | 19 |
| award, contract | UK6 contract award | 17 |
| planning | UK2 preliminary market engagement | 9 |
| tenderUpdate | UK4 tender | 9 |
| award, contract | UK5 transparency (direct award) | 6 |
| planningUpdate | UK2 preliminary market engagement | 4 |
| award, contract | UK15 dynamic market modification | 3 |
| planning | UK1 pipeline | 2 |
| tenderCancellation | UK12 procurement termination | 1 |
| awardUpdate, contractUpdate | UK6 contract award | 1 |
| contractAmendment | UK10 contract change | 1 |

22 notices have no `noticeType`: older-regime notices or notices without documents.

## Field coverage

Out of 151 notices:

| Field | Notices |
|---|---|
| `awards` present | 102 |
| `contracts[].value.amount` | 66 |
| `tender.items[].additionalClassifications[].id` (CPV) | 54 |
| `tender.value.amount` | 34 |
| `tender.tenderPeriod.endDate` (closing date) | 27 |
| `tender.classification.id` (CPV) | 22 |
| `awards[].value.amount` | 20 |

## Buyers

The most active buyer had 7 notices (National Gallery); the rest had 3 or fewer. Buyer names vary in case (e.g. `CAMBRIDGE UNIVERSITY HOSPITALS NHS FOUNDATION TRUST`), so group by buyer `id`, not name.

## Personal data

`parties[].contactPoint` holds names, emails and phone numbers. Staging removes it everywhere, including from the stored notice JSON, and a test enforces this ([ADR 0016](adr/0016-strip-contact-details-in-staging.md)). Free-text fields (descriptions, submission details) can still contain email addresses: treat them as possibly personal.

## Awards (rules for `fct_award_suppliers`)

**Sample:** `TENDER_DB.DEV_STAGING` rebuilt on 2026-10-07 at 20:44 UTC after the backfill: 75,155 notices published 2025-02-24 to 2026-10-07, 53,927 distinct awards. A first pass on 25 hours of data (523 notices, 418 awards) pointed the same way; the numbers below replace it. Queries: `snowflake/eda/award_findings.sql`.

### Where award data lives

| Notice type | Award rows | Distinct awards | With award date | With award value |
|---|---|---|---|---|
| Old regime (no notice type) | 29,255 | 29,255 | 0% | 0% |
| UK7 contract details | 17,439 | 17,360 | 0% | 0% |
| UK6 contract award | 7,541 | 7,393 | 99% | 99% |
| UK5 transparency | 3,137 | 3,063 | 0% | 100% |
| UK15 dynamic market modification | 2,301 | 135 | 0% | 0% |
| UK12 procurement termination | 661 | 659 | 0% | 0% |
| UK14 dynamic market establishment | 150 | 150 | 0% | 0% |
| UK10 contract change | 3 | 3 | 0% | 0% |

- Award value and date sit on UK6 (value also on UK5); UK7 repeats the award without them, so values and dates must be collected across all notices of an award, not taken from the latest.
- Most values are on the contract: chosen value comes from contract net for 36,264 awards, award net 7,229, award gross 1,508, contract gross 2,410; 5,776 have no value.
- Every award has at most one contract; 8,172 have none. Where award and contract net both exist (1,925), they are equal in 1,710 (89%).
- Gross exceeds 2× net on 81 awards (outliers; gross is normally net × 1.2, VAT).
- Dates: award date 7,289, contract signed date 43,429, publication date 2,469. Where both exist, award to signature takes a median of 20 days.
- UK14 and UK15 are dynamic-market admissions, not awards: no value, no date.
- 605 awards are cancelled (latest status), 3,985 pending.
- 2,328 awards (outside UK15) have no supplier listed.
- 104 awards have different buyer IDs and 238 different CPV codes across their notices: take them from the latest notice.
- Currencies other than GBP on 66 awards (EUR 35, USD 21, and 8 others); all but a handful have an HMRC rate.

### Values: frameworks and implausible amounts

Value in GBP (£m), excluding UK15 and cancelled awards, by framework detection (framework field, 3+ suppliers or "framework" in the title):

| Group | Awards | £m |
|---|---|---|
| Other awards, Procurement Act | 21,883 | 27,693 |
| Other awards, old regime | 19,602 | 686,979 |
| Framework set-ups, old regime | 9,653 | 1,315,017 |
| Framework set-ups, Procurement Act | 2,049 | 238,793 |

- Framework ceilings dominate, as expected.
- Old-regime "other" awards are not plausible at £687bn: they include undetected frameworks and data-entry errors. Examples: £100bn "Travel Management Services", Cabinet Office facilities management £35bn (a framework without the word), a council road scheme at £21.2bn (likely £21.2m).
- 335 old-regime contracts of £1bn or more total £1.48tn of £2.0tn.

Non-framework GBP awards by size:

| | Procurement Act | Old regime |
|---|---|---|
| Awards | 21,693 | 16,735 |
| Median value | £64k | £172k |
| 99th percentile | £12.6m | £655m |
| Awards ≥ £100m | 36 | 489 |
| Awards ≥ £1bn | 2 | 119 |
| Total | £28bn | £687bn |
| Total below £100m | £13bn | £44bn |

**Decision: flag awards of £100m or more** (`is_large_value`, threshold in the dbt var `large_award_gbp`). They are left out of the headline totals on "Who's buying?" and "Who's winning?" and listed separately for review. 99% of Procurement Act awards are under £12.6m, yet the 36 above £100m hold half the Act total; above £100m the old regime is mostly undetected frameworks and data-entry errors.

### Staging issues found by the full data (fixed)

- Notices with no legal basis gave `is_procurement_act` = NULL instead of FALSE (2 notices, March 2025).
- Currency tests expected only GBP, EUR and USD: replaced by "has an HMRC rate", skipping GBP (the base currency).
- 3 awards list the same supplier twice: `stg_find_a_tender__award_suppliers` keeps one copy.
- A party ID can appear twice in a notice (one organisation in two roles, branches sharing a company number, publisher errors): `stg_find_a_tender__parties` is keyed by position.

### Assumptions for the fact

- Value: award net, else contract net, else award gross, else contract gross, across all notices of the award; labelled net or gross.
- Date: earliest award date, else contract signed date, else publication date; the same date picks the exchange-rate month.
- Pending awards count as awarded; cancelled awards and UK14/UK15 admissions don't.
- Framework set-ups are left out of the headline numbers and shown separately; call-offs count as normal awards.
- Joint awards are split equally between distinct suppliers.
- Old-regime awards are included, using the contract value.
- Awards of £100m or more are flagged and left out of headline totals, but listed.
