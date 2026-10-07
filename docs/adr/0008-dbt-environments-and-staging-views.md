# 0008. dbt: dev and prod by schema, staging as views

Status: Accepted (2026-10-07); "staging as views" superseded by [0015](0015-staging-as-tables.md), schema naming by [0024](0024-prod-schema-prefix.md). Details: [dbt.md](../dbt.md).

## Context
dbt needs separate dev and prod outputs, and staging must stay current with raw data.

## Decision
- One database, `TENDER_DB`. `RAW` is shared and read-only for dbt.
- A custom `generate_schema_name` macro: the `prod` target writes to `STAGING` / `MARTS`, every other target to `<target schema>_STAGING` (e.g. `DEV_STAGING`).
- Staging models are views; deduplicate on notice `id`, latest load wins; personal data (`contactPoint`) is dropped.
- dbt Core is installed in a separate uv dependency group, so loader CI and deploys don't install it.

## Consequences
- Developers can't overwrite prod; no database clones to manage.
- Staging costs nothing to build; marts will be tables for dashboard speed.
- Separate databases per environment only become worthwhile with several developers or separate raw data.
