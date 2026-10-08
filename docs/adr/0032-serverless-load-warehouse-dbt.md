# 0032. Serverless compute for the load, a warehouse for dbt

Status: Accepted (2026-10-08). Expands the compute choices in [ADR 0001](0001-run-ingestion-in-snowflake.md) and [ADR 0009](0009-run-dbt-on-a-schedule-in-snowflake.md).

## Context
Snowflake runs a task either on **serverless** compute (Snowflake sizes and starts it, billed per second of run time) or on a **warehouse** (billed per second while running, with at least 60 seconds per resume, and until it auto-suspends; `TENDER_WH` suspends after 60 seconds idle). Serverless compute costs more per second than a warehouse of the same size, so which is cheaper depends on how long and how often a job runs.

The load is short and frequent: about 25 seconds, 5 times a day. dbt runs about 70 seconds, 5 times a day, 20 minutes after each load.

## Decision
- **The load runs serverless.** `RAW.INGEST_FIND_A_TENDER` has no warehouse; its size is pinned to SMALL (`SERVERLESS_TASK_MIN_STATEMENT_SIZE` = `MAX` = `SMALL`, in `03_ingest_task.sql`).
- **dbt runs on `TENDER_WH`.** It has to: a dbt project object (`EXECUTE DBT PROJECT`) can't run in a serverless task, and the task must sit in the project's schema (`DBT`). The warehouse is X-Small and suspends after 60 seconds idle.

Measured on this account (2026-10-07 to 08, `SNOWFLAKE.ACCOUNT_USAGE`):

| | Load as serverless (chosen) | Same load on `TENDER_WH` (X-Small) |
|---|---|---|
| Per run | **~0.001–0.002 credits** (0.0133 credits for the last ~10 runs) | **~0.033 credits**: at least 60 s billed on resume plus 60 s idle before suspend, for a 25 s job |
| Per month (5 loads a day) | **~0.2–0.3 credits** | **~5 credits** |

Serverless wins for the load because there is no 60-second minimum and no idle tail: only the 25 seconds of work are billed. For a long job (around 10 minutes or more) a warehouse is cheaper, which is why running dbt on `TENDER_WH` costs little extra.

## Consequences
- The load costs about 20–30 times less than it would on the warehouse, and never waits behind dbt or Power BI queries on `TENDER_WH`.
- `TENDER_WH` resumes twice per cycle (dbt, then the Power BI refresh), about 0.3–0.4 credits on a normal day; days with development, CI builds and manual queries cost more.
- Serverless spend isn't covered by warehouse resource monitors; check it in `METERING_HISTORY` or Admin → Cost management.
- To check the figures again:

```sql
SELECT
    COUNT(*) AS billed_intervals,
    ROUND(SUM(credits_used), 4) AS credits
FROM
    SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
WHERE
    task_name = 'INGEST_FIND_A_TENDER'
    AND start_time > DATEADD('day', -2, CURRENT_TIMESTAMP());
```
