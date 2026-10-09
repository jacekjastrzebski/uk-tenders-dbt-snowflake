# DataOps review

Status: review of 7 October 2026, after ingestion moved into Snowflake and the first dbt staging models. Gaps are ordered by priority. Updated 9 October 2026: gaps 1, 2, 4 and 5 and the backfill are done; 3 and the remaining smaller points are open.

## In place

- **Version control and review:** every change goes through a branch and PR; CI runs pre-commit, mypy and pytest.
- **CD for ingestion:** merging to `main` deploys only the changed Snowflake objects (`.github/workflows/deploy.yml`), as least-privilege service user `TENDER_DEPLOY`. Secrets in GitHub; no keys in the repo.
- **Reliable loads:** idempotent windows from the last successful run, a runs table, task timeout, no overlapping runs, auto-suspend after 3 failures, failure email alert.
- **Separate roles:** `TENDER_INGEST` (load), `TENDER_TRANSFORM` (dbt); admin roles only for setup.
- **Dev/prod separation for dbt:** the `dev` target writes to `DEV_*` schemas.
- **Personal data** stays in `RAW` (`parties[].contactPoint` is dropped in staging).
- **Data quality:** dbt tests on every staging model, source freshness.
- **Pinned dependencies** (`uv.lock`, Snowflake CLI version) and docs for setup, operations and checks.

## Gaps

### 1. dbt is not in CI
**Done:** pull requests that change `dbt/` build and test it in `CI_PR_<n>_*` schemas, as its own user `TENDER_CI`, and `dbt` is a required check ([ADR 0030](../adr/0030-build-dbt-in-ci.md), [ADR 0033](../adr/0033-pipeline-safeguards.md)).

Nothing checks that models build and tests pass before a merge.

Plan: a CI job on pull requests that runs `dbt build` into a temporary schema (e.g. `PR_<number>`) as a CI service user with role `TENDER_TRANSFORM`, then drops the schema. Later: only build changed models (`--select state:modified+` against the prod manifest).

### 2. dbt has no prod deploy or schedule
**Done:** deployed as a dbt Project on Snowflake and run by task `DBT.RUN_DBT` 20 minutes after each load ([ADR 0009](../adr/0009-run-dbt-on-a-schedule-in-snowflake.md)).

dbt runs only from a laptop.

Plan: [dbt-orchestration.md](dbt-orchestration.md). Deploy the project as a dbt Project on Snowflake from `deploy.yml` when `dbt/` changes, and run it from a task scheduled 20 minutes after each load, with the `prod` target writing to `PROD_STAGING` / `PROD_MARTS`.

### 3. Setup scripts are not fully reproducible
**Open.**

`snowflake/setup/` and `00`/`01` in `snowflake/native_ingestion/` are run by hand, so Snowflake can drift from the repo. Known drift: SYSADMIN still holds the grants from the earlier version of `01_external_access.sql` (USAGE on both integrations, EXECUTE [MANAGED] TASK/ALERT).

Plan: revoke the leftover SYSADMIN grants now; later consider declarative tooling (Terraform Snowflake provider or schemachange).

### 4. Monitoring misses quiet failures
**Done:** source freshness runs first in every dbt run and counts only pages with notices; alert `PIPELINE_STALE` emails when no load or dbt run has succeeded for 4 hours, and `POWERBI_REFRESH_MISSED` when Power BI stops reading the marts ([ADR 0033](../adr/0033-pipeline-safeguards.md), [ADR 0031](../adr/0031-alert-when-power-bi-stops-refreshing.md)).

A load that succeeds with 0 releases for days raises no alert; source freshness would catch it but is not scheduled.

Plan: run `dbt source freshness` with the scheduled dbt run, and fold it into the event-based alerting already on the README TO-DO list.

### 5. No cost guardrail
**Done for the warehouse:** resource monitor `TENDER_WH_MONITOR` (30 credits a month) and a 30-minute statement timeout; the guest warehouse has its own 1-credit monitor ([ADR 0033](../adr/0033-pipeline-safeguards.md), [ADR 0029](../adr/0029-guest-role-with-capped-warehouse.md)). Serverless loads and alerts are not covered; review them in `METERING_HISTORY`.

No resource monitor or credit cap on the account.

Plan: a resource monitor with a monthly credit quota, notify at 75%, suspend at 100%, assigned to the account (serverless tasks and alerts are not covered by warehouse monitors, so also review `METERING_HISTORY` monthly).

### 6. Smaller points
- GitHub Actions are pinned to version tags, not commit SHAs.
- Key rotation for `TENDER_DEPLOY` and personal keys is not documented.
- No historical backfill, so the data cannot be rebuilt from scratch. **Done:** backfilled from 24 February 2025 ([ADR 0017](../adr/0017-backfill-from-procurement-act-start.md)).
