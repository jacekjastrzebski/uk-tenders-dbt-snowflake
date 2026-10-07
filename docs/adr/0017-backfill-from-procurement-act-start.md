# 0017. Backfill from 24 February 2025, through the API

Status: Accepted (2026-10-07)

## Context
The scheduled load only fetches notices updated since its last run, so the first loads held about one day of notices ([eda-findings.md](../eda-findings.md)). The report needs history: trends over the last 12 months, and tender-to-award timings for procurements that started earlier.

The Procurement Act 2023 came into force on 24 February 2025. From that date notices carry a notice type (UK1–UK17, [procurement primer](../procurement-primer.md)), which the models classify by ([ADR 0007](0007-classify-notices-by-notice-type.md)).

The API returns past windows: a test on 2026-10-07 fetched 207 notices for 4 March 2025 and 527 for 3 March 2026.

## Decision
- Backfill from **24 February 2025**: every Procurement Act notice, about 20 months, not only the last 12.
- Fetch it through the same API and loader as the scheduled load, one day per run, not from the Open Contracting data registry's bulk files.
- Run it inside Snowflake as `TENDER_INGEST` (procedure `RAW.BACKFILL_FIND_A_TENDER_RELEASES`), like the scheduled load ([ADR 0001](0001-run-ingestion-in-snowflake.md), [ADR 0004](0004-least-privilege-roles-and-deploy-user.md)), so it reuses the API access integration and needs no laptop.

## Consequences
- The report can show a rolling 12 months and still have earlier tenders for procurements awarded inside that window.
- About 150–200k notices, roughly 2,000 API pages; estimated at about an hour.
- Same JSON format and the same raw table, so staging and marts need no changes.
- Older-regime notices published before 24 February 2025 are not loaded, except those updated later, which the scheduled load picks up.
