# 0015. Staging models as tables; layers named the dbt way

Status: Accepted (2026-10-07). Supersedes the "staging as views" part of [0008](0008-dbt-environments-and-staging-views.md). Numbered 0015 because 0013 and 0014 are on the research branch `research/gold-powerbi`. Schema names superseded by [0024](0024-prod-schema-prefix.md).

## Context
Staging started as views, so the expensive JSON work (flattening pages, deduplicating, finding the notice type) was repeated every time a child model, a mart or a query read it. The intended flow is ELT in three layers: data as fetched, then cleaned and stored, then dashboard tables. The medallion names (bronze, silver, gold) and the dbt names (raw, staging, marts) describe the same layers.

## Decision
- Use dbt's names: **raw → staging → marts**. Schemas `RAW`, `STAGING`, `MARTS` (`DEV_` prefix in dev). Medallion equivalents are listed in the glossary.
- Materialise staging models as **tables**: built once per dbt run, read cheaply by marts and ad-hoc queries.

## Consequences
- Each run rebuilds staging in full: seconds now; switch the notices model to incremental (new pages only) when history grows.
- Staging is only as fresh as the last dbt run, not live like a view; dbt runs after each load ([0009](0009-run-dbt-on-a-schedule-in-snowflake.md)).
- Storage for a second, cleaned copy of the data: small (no raw JSON payloads except the `notice` column).
