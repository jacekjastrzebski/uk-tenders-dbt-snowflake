# Running dbt in Snowflake after each load

Status: built (2026-10-08, ADR 0009); kept for the reasoning. Closes gap 2 of the [DataOps review](dataops-review.md).

## Goal

After each load, run `dbt build --target prod` inside Snowflake, so `PROD_STAGING` and `PROD_MARTS` reflect the latest raw data. No laptop, no GitHub Actions schedule.

## Design: one scheduled task, 20 minutes after each load

Loads run every day at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time and take about a minute, so dbt runs at :20 past the same hours:

```
:00  INGEST_FIND_A_TENDER  (RAW, role TENDER_INGEST, serverless)
:20  RUN_DBT               (DBT, role TENDER_TRANSFORM, warehouse TENDER_WH)
:30  failure alert         (checks both tasks)
```

```sql
CREATE TASK TENDER_DB.DBT.RUN_DBT
  WAREHOUSE = TENDER_WH
  SCHEDULE = 'USING CRON 20 7,10,13,16,19 * * * Europe/London'
  USER_TASK_TIMEOUT_MS = 1800000          -- 30 minutes
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
AS
BEGIN
  EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'source freshness --target prod';
  EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'build --target prod';
END;
```

- `source freshness` first: if raw data is older than the error threshold (26 h), the task fails before building and the failure alert emails. Warnings (13 h) are only logged.
- `dbt build` runs models and tests in dependency order, so a failing test stops the models that depend on it. It does not include freshness, hence the separate step.

## Constraints from the Snowflake docs

| Constraint | Consequence |
|---|---|
| dbt project objects can't run in serverless tasks | The task uses warehouse `TENDER_WH` (X-Small, suspends after 60 s idle) |
| The task must be in the same schema as the dbt project object | New schema `TENDER_DB.DBT`, owned by `TENDER_TRANSFORM` |
| All tasks in a task graph need the same owner, database and schema | dbt can't be chained `AFTER` the load without merging the ingest and transform roles, hence the schedule |

## Setup

- **Privileges** (`snowflake/setup/03_transform_role.sql`): `EXECUTE TASK` on the account for `TENDER_TRANSFORM`, plus the privileges to create and run dbt project objects (exact names to confirm when building).
- **Deploy** (`deploy.yml`, when `dbt/**` changes): `snow dbt deploy UK_TENDERS --source dbt --database TENDER_DB --schema DBT`, as `TENDER_DEPLOY` with role `TENDER_TRANSFORM` granted. The project ships a credential-free `prod` profile; Snowflake supplies the session.
- **Alerting**: the failure alert (`04_failure_alert.sql`) filters on `INGEST_FIND_A_TENDER%`; extend the filter to `RUN_DBT`.

## Trade-off

If a load ever takes longer than 20 minutes, dbt runs on the previous load's data and the next run catches up. Staging and marts are rebuilt in full each run, so nothing is lost.

## Later, if needed

If loads become irregular or slow, trigger dbt when a load finishes instead: an append-only stream on `RAW.FIND_A_TENDER_INGEST_RUNS` (one row per finished load) and a task with `WHEN SYSTEM$STREAM_HAS_DATA(...)` instead of a schedule. The task must consume the stream with an insert before running dbt.

## Verification (when built)

1. After a load, task history shows `RUN_DBT` succeeded at :20 and `PROD_STAGING` row counts include the new notices.
2. A deliberately failing test → task FAILED and the alert email arrives.
