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

**Sample:** `TENDER_DB.DEV_STAGING` rebuilt on 2026-10-07 at 22:50 UTC after the backfill finished: 172,312 notices published 2025-02-24 to 2026-10-07 (all 21 months), 119,032 distinct awards. Earlier passes on 25 hours of data and on a partial backfill pointed the same way; the numbers below replace them. Queries: `snowflake/eda/award_findings.sql`.

### Where award data lives

| Notice type | Award rows | Distinct awards | With award date | With award value |
|---|---|---|---|---|
| UK7 contract details | 53,817 | 53,083 | 0% | 0% |
| Old regime (no notice type) | 48,601 | 48,601 | 0% | 0% |
| UK6 contract award | 25,307 | 24,347 | 99% | 99% |
| UK15 dynamic market modification | 10,263 | 197 | 0% | 0% |
| UK5 transparency | 7,671 | 7,481 | 0% | 100% |
| UK12 procurement termination | 1,919 | 1,913 | 0% | 0% |
| UK14 dynamic market establishment | 300 | 300 | 0% | 0% |
| UK10 contract change | 10 | 10 | 0% | 0% |

- Award value and date sit on UK6 (value also on UK5); UK7 repeats the award without them, so values and dates must be collected across all notices of an award, not taken from the latest.
- Most values are on the contract: the chosen value comes from contract net for 75,928 awards, award net 22,434, award gross 4,373, contract gross 5,721; 8,725 have no value.
- Every award has at most one contract; 18,764 have none. Where award and contract net both exist (10,101), they are equal in 9,084 (90%).
- Gross exceeds 2× net on 243 awards (outliers; gross is normally net × 1.2, VAT).
- Dates: award date 23,917, contract signed date 88,364, publication date 4,900. Where both exist, award to signature takes a median of 25 days.
- UK14 and UK15 are dynamic-market admissions, not awards: no value, no date.
- 1,654 awards are cancelled (latest status), 8,030 pending.
- 4,723 awards (outside UK15) have no supplier listed.
- 370 awards have different buyer IDs and 783 different CPV codes across their notices: take them from the latest notice.
- Currencies other than GBP on 165 awards (EUR 72, USD 51, PKR 17, and about 20 others); almost all have an HMRC rate.

### Values: frameworks and implausible amounts

Value in GBP (£m), excluding UK14, UK15 and cancelled awards, by framework detection (framework field, 3+ suppliers or "framework" in the title):

| Group | Awards | £m |
|---|---|---|
| Other awards, Procurement Act | 61,378 | 176,938 |
| Other awards, old regime | 35,215 | 1,091,304 |
| Framework set-ups, old regime | 13,386 | 1,741,220 |
| Framework set-ups, Procurement Act | 7,202 | 2,270,624 |

- Framework ceilings dominate, as expected.
- "Other" awards still include undetected frameworks and data-entry errors. Examples: £100bn "Travel Management Services", Cabinet Office facilities management £35bn (a framework without the word), a council road scheme at £21.2bn (likely £21.2m).

Non-framework GBP awards by size:

| | Procurement Act | Old regime |
|---|---|---|
| Awards | 60,688 | 30,505 |
| Median value | £73k | £168k |
| 99th percentile | £24.2m | £560m |
| Awards ≥ £100m | 218 | 773 |
| Awards ≥ £1bn | 20 | 203 |
| Total | £177bn | £1,091bn |
| Total below £100m | £52bn | £79bn |

**Decision: flag awards of £100m or more** (`is_large_value`, threshold in the dbt var `large_award_gbp`). They are left out of the headline totals on "Who's buying?" and "Who's winning?" and listed separately for review. 99% of Procurement Act awards are under £24.2m, yet the 218 above £100m hold £125bn of the £177bn Act total; above £100m the old regime is mostly undetected frameworks and data-entry errors.

### Source quirks found and handled

- Notices with no legal basis gave `is_procurement_act` = NULL instead of FALSE.
- Currency tests expected only GBP, EUR and USD: replaced by "has an HMRC rate", skipping GBP (the base currency).
- A few awards list the same supplier twice: `stg_find_a_tender__award_suppliers` keeps one copy.
- A party ID can appear twice in a notice (one organisation in two roles, branches sharing a company number, publisher errors): `stg_find_a_tender__parties` is keyed by position.
- One Procurement Act notice in 172,000 has no notice type: the consistency test warns instead of failing.
- 17 empty contract entries (no id, award, value or date) are skipped.
- Award or signed dates outside the calendar (e.g. "signed" in 1961) are treated as unknown; the next date source is used.

### Assumptions for the fact

- Value: award net, else contract net, else award gross, else contract gross, across all notices of the award.
- Date: earliest award date, else contract signed date, else publication date; the same date picks the exchange-rate month.
- Pending awards count as awarded; cancelled awards and UK14/UK15 admissions don't.
- Framework set-ups are left out of the headline numbers and shown separately; call-offs count as normal awards.
- Joint awards are split equally between distinct suppliers.
- Old-regime awards are included, using the contract value, but left out of the headline totals since [ADR 0034](adr/0034-award-data-corrections.md).
- Awards of £100m or more are flagged and left out of headline totals, but listed.
