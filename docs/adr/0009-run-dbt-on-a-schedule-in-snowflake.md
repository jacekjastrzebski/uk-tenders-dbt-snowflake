# 0009. Run dbt in Snowflake, 20 minutes after each load

Status: Accepted (2026-10-08), built in `snowflake/dbt/`; proposed 2026-10-07. Details: [plans/dbt-orchestration.md](../plans/dbt-orchestration.md), usage in [dbt.md](../dbt.md#runs-in-snowflake). The last consequence's open question is answered in [0033](0033-pipeline-safeguards.md): a failed dbt command fails the task.

## Context
dbt must run after each load, without a laptop. Options: chain `AFTER` the ingest task, a triggered task on a stream, or a schedule. Tasks in one graph need the same owner and schema, so chaining would merge the ingest and transform roles. A triggered task needs a stream, a table to consume it, and change tracking.

## Decision
Deploy the project as a dbt Project on Snowflake and run it from one task at `20 7,10,13,16,19 * * *` (warehouse `TENDER_WH`; dbt projects can't run serverless): `source freshness`, then `build --target prod`.

As built:
- The project object `TENDER_DB.DBT.UK_TENDERS`, task `RUN_DBT` and alert `RUN_DBT_FAILED` all sit in schema `DBT`, owned by `TENDER_TRANSFORM`. The task must be in the project's schema.
- `snow dbt deploy` deploys it from GitHub Actions (`deploy.yml`) whenever `dbt/` changes, adding a new version and keeping the run history. `TENDER_DEPLOY` holds `TENDER_TRANSFORM` for this.
- The profile, `snowflake/dbt/profiles.yml`, has only a `prod` output and no account, user or password: Snowflake runs the project in its own session.
- A separate alert emails when `RUN_DBT` fails. The ingest alert runs as `TENDER_INGEST` and can't see this task.

## Consequences
- One task, no stream; loads take about a minute, so :20 is safely after.
- A load slower than 20 minutes means dbt uses the previous data until the next run.
- Upgrade path if loads become irregular: a triggered task on the runs table.
- The task runs on `TENDER_WH` for about a minute per run, which is billed; the load itself stays serverless.
- Not verified when built: whether a failed dbt command makes `EXECUTE DBT PROJECT`, and so the task, fail. Snowflake documents a success flag in its result. Check once after the first deploy (see dbt.md).
