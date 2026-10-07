# DataOps review

Status: review of 7 October 2026, after ingestion moved into Snowflake and the first dbt staging models. Gaps are ordered by priority; recommended next: 1, 2 and 5.

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
Nothing checks that models build and tests pass before a merge.

Plan: a CI job on pull requests that runs `dbt build` into a temporary schema (e.g. `PR_<number>`) as a CI service user with role `TENDER_TRANSFORM`, then drops the schema. Later: only build changed models (`--select state:modified+` against the prod manifest).

### 2. dbt has no prod deploy or schedule
dbt runs only from a laptop.

Plan: [dbt-orchestration.md](dbt-orchestration.md). Deploy the project as a dbt Project on Snowflake from `deploy.yml` when `dbt/` changes, and run it from a task scheduled 20 minutes after each load, with the `prod` target writing to `PROD_STAGING` / `PROD_MARTS`.

### 3. Setup scripts are not fully reproducible
`snowflake/setup/` and `00`/`01` in `snowflake/native_ingestion/` are run by hand, so Snowflake can drift from the repo. Known drift: SYSADMIN still holds the grants from the earlier version of `01_external_access.sql` (USAGE on both integrations, EXECUTE [MANAGED] TASK/ALERT).

Plan: revoke the leftover SYSADMIN grants now; later consider declarative tooling (Terraform Snowflake provider or schemachange).

### 4. Monitoring misses quiet failures
A load that succeeds with 0 releases for days raises no alert; source freshness would catch it but is not scheduled.

Plan: run `dbt source freshness` with the scheduled dbt run, and fold it into the event-based alerting already on the README TO-DO list.

### 5. No cost guardrail
No resource monitor or credit cap on the account.

Plan: a resource monitor with a monthly credit quota, notify at 75%, suspend at 100%, assigned to the account (serverless tasks and alerts are not covered by warehouse monitors, so also review `METERING_HISTORY` monthly).

### 6. Smaller points
- GitHub Actions are pinned to version tags, not commit SHAs.
- Key rotation for `TENDER_DEPLOY` and personal keys is not documented.
- No historical backfill, so the data cannot be rebuilt from scratch.
