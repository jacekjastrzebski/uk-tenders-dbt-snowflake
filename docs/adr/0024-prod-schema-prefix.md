# 0024. Prefix prod schemas with PROD_

Status: Accepted (2026-10-08). Supersedes the schema naming in [0008](0008-dbt-environments-and-staging-views.md) and [0015](0015-staging-as-tables.md).

## Context
Dev schemas were `DEV_STAGING`, `DEV_MARTS`, but prod used bare names (`STAGING`, `MARTS`), which needed a custom `generate_schema_name` macro. A CI environment would add a third pattern.

## Decision
- Every environment is `<target schema>_<folder schema>`: `PROD_STAGING`, `PROD_INTERMEDIATE`, `PROD_MARTS` in prod, `DEV_*` in dev (later `CI_*`).
- This is dbt's default naming, so the custom macro is removed. The prod target's schema is `PROD` (an empty schema the dbt project in Snowflake needs to exist; `03_transform_role.sql`).
- `TENDER_REPORTER` reads `PROD_MARTS` and `DEV_MARTS` (`04_reporting_role.sql`).

## Consequences
- One naming rule everywhere, one macro less.
- The old `STAGING`, `INTERMEDIATE` and `MARTS` schemas are dropped once the prod build has run into the new ones.
