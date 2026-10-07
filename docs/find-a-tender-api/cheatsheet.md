# Find a Tender OCDS API: cheatsheet

Quick reference for the release package API. Full specs: [overview](overview.md), [release packages](ocds-release-packages.md), [record packages](ocds-record-packages.md). Examples are from notices published on 6 October 2026.

## 1. Endpoint

```
GET https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages
```

Plain HTTP GET. No API key, no login.

## 2. Parameters

| Parameter | Meaning | Example |
|---|---|---|
| `updatedFrom` | Notices updated at or after this time | `2026-10-06T17:00:00` |
| `updatedTo` | Notices updated up to this time | `2026-10-06T18:00:00` |
| `limit` | Notices per page, 1–100 (default 100) | `100` |
| `cursor` | Token for the next page; take it from `links.next`, never build it | |
| `stages` | `planning`, `tender`, `award` | Avoid: reported to drop notices; filter in dbt instead |

Dates have no time zone (`YYYY-MM-DDTHH:MM:SS`). The docs don't say which one; tests show the API reads them as **UK local time** (BST in summer), so send `Europe/London` times ([ADR 0018](../adr/0018-api-dates-in-uk-local-time.md)).

Single items:

- `/ocdsReleasePackages/094475-2026`: one notice (notice ID `nnnnnn-yyyy`)
- `/ocdsReleasePackages/ocds-h6vhtk-078217`: every notice for one procurement (ocid)

## 3. Response: a release package

```
{
  uri, version, publishedDate, publisher, license, ...   wrapper metadata
  releases: [ ... up to `limit` notices ... ]            the data
  links: { next: "...&cursor=..." }                      only when more pages exist
}
```

Paging: call the URL, process `releases`, call `links.next`, stop when `next` is missing.

Real example with 4 releases (contact details redacted): [samples/release-package-limit-4.json](samples/release-package-limit-4.json).

## 4. A release = one published notice

| Field | Meaning | Example |
|---|---|---|
| `id` | Notice ID | `094475-2026` |
| `ocid` | Procurement ID, shared by all its notices | `ocds-h6vhtk-078217` |
| `date` | Publication time, UK local with offset | `2026-10-06T17:48:47+01:00` |
| `tag` | OCDS stage label; coarse, so classify notices by `noticeType` instead ([EDA findings](../eda-findings.md)) | `["award", "contract"]` |
| `parties[]` | Organisations, each with `roles` (buyer, supplier, reviewBody) | `contactPoint` holds **personal data**: name, email, telephone |
| `buyer` | Reference to the buyer in `parties` | `{id, name}` |
| `tender` | What is bought: title, value, lots, deadlines | |
| `awards[]` | Winners, values, award dates | |
| `contracts[]` | Signed contracts | |

The Procurement Act notice type (UK1–UK17) is in `documents[].noticeType` inside `planning`, `tender`, `awards` or `contracts`, not at the top level.

## 5. How notices connect

One procurement (`ocid`) gets several notices (`id`) over time. Example, "eSourcing Tendering Platform":

| Published | Notice ID | Type |
|---|---|---|
| 17:38 | `094469-2026` | UK5 transparency (direct award) |
| 17:48 | `094475-2026` | UK6 award |

Group by `ocid`, order by `date` and notice type to build the lifecycle.

## 6. Errors

| Code | Meaning | Action |
|---|---|---|
| 400 | Unknown parameter name | Fix the request |
| 429 | Too many requests | Wait `Retry-After` seconds, retry |
| 503 | Service unavailable | Wait `Retry-After` seconds, retry |

## 7. Observations from real data

- CPV code is usually empty in `tender.classification` for Procurement Act notices; look in `items[].additionalClassifications`.
- Old-regime notices still appear: no `noticeType`, but CPV in `tender.classification`.
- About 7 KB per release; a full page of 100 is about 700 KB uncompressed.
- `ocdsRecordPackages/{ocid}` returns all releases for one procurement plus a compiled current state. Useful for checking one case, not for bulk loads.

## 8. Try it

```bash
curl -s "https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages/ocds-h6vhtk-078217" \
  | python3 -m json.tool | less
```

Or fetch the last N hours to `data/samples/`:

```bash
python3 ingestion/explore_find_a_tender.py 3
```
