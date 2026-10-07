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

`parties[].contactPoint` holds names, emails and phone numbers. Staging models leave it out.
