# 0009. Run dbt in Snowflake, 20 minutes after each load

Status: Proposed (2026-10-07), not built. Details: [plans/dbt-orchestration.md](../plans/dbt-orchestration.md).

## Context
dbt must run after each load, without a laptop. Options: chain `AFTER` the ingest task, a triggered task on a stream, or a schedule. Tasks in one graph need the same owner and schema, so chaining would merge the ingest and transform roles. A triggered task needs a stream, a table to consume it, and change tracking.

## Decision
Deploy the project as a dbt Project on Snowflake and run it from one task at `20 7,10,13,16,19 * * *` (warehouse `TENDER_WH`; dbt projects can't run serverless): `source freshness`, then `build --target prod`.

## Consequences
- One task, no stream; loads take about a minute, so :20 is safely after.
- A load slower than 20 minutes means dbt uses the previous data until the next run.
- Upgrade path if loads become irregular: a triggered task on the runs table.
