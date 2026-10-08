-- Run dbt in Snowflake 20 minutes after each load (ADR 0009), and email if it fails or if
-- the data stops moving (ADR 0033).
-- Loads run at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time and take about a minute.
-- The dbt project object TENDER_DB.DBT.UK_TENDERS is deployed by .github/workflows/deploy.yml
-- (snow dbt deploy); this script is deployed there too, filling in the alert recipient. By hand:
--   snow sql -f snowflake/dbt/01_run_dbt_task.sql -D alert_email=<you> -c tender
USE ROLE TENDER_TRANSFORM;

-- dbt projects can't run in serverless tasks, and the task must sit in the project's schema.
-- Freshness first: raw data older than 26 hours fails the task before anything is rebuilt.
-- Any dbt failure (freshness error, failed model or test) raises an error, so the run fails.
CREATE OR REPLACE TASK TENDER_DB.DBT.RUN_DBT
  WAREHOUSE = TENDER_WH
  SCHEDULE = 'USING CRON 20 7,10,13,16,19 * * * Europe/London'
  USER_TASK_TIMEOUT_MS = 1800000         -- stop a stuck run after 30 minutes
  ALLOW_OVERLAPPING_EXECUTION = FALSE
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  AS
    EXECUTE IMMEDIATE $$
    BEGIN
      EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'source freshness --target prod';
      EXECUTE DBT PROJECT TENDER_DB.DBT.UK_TENDERS ARGS = 'build --target prod';
    END;
    $$;

-- Tasks are created suspended
ALTER TASK TENDER_DB.DBT.RUN_DBT RESUME;

-- Email when a dbt run failed, timed out or was cancelled since the previous check.
-- The window runs from the last check to this one, by when each run ended, so a run the
-- 30-minute timeout stops at :50 is caught by the next check, even the next morning.
-- After a redeploy the alert has no last check yet, so it looks back 3 hours.
-- Separate from the ingest alert: that one runs as TENDER_INGEST, which can't see this task.
CREATE OR REPLACE ALERT TENDER_DB.DBT.RUN_DBT_FAILED
  SCHEDULE = 'USING CRON 50 7,10,13,16,19 * * * Europe/London'
  IF (EXISTS (
    SELECT
        1
    FROM
        TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT', ERROR_ONLY => TRUE))
    WHERE
        completed_time > COALESCE(
            SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME(),
            DATEADD('hour', -3, SNOWFLAKE.ALERT.SCHEDULED_TIME())
        )
        AND completed_time <= SNOWFLAKE.ALERT.SCHEDULED_TIME()
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'TENDER_EMAIL',
      '<% alert_email %>',
      'Find a Tender dbt run failed',
      'A scheduled dbt run failed. Check TASK_HISTORY for TENDER_DB.DBT.RUN_DBT and the dbt project run history in Snowsight.'
    );

-- Alerts are created suspended
ALTER ALERT TENDER_DB.DBT.RUN_DBT_FAILED RESUME;

-- Email when the data stops moving: no successful load, or no successful dbt run, in the
-- last 4 hours, checked by day after each dbt run. The failure alerts only see runs that
-- failed; this one also sees runs that never happen, e.g. once a task has suspended itself
-- after 3 failures in a row. It emails at every check until both have caught up.
-- Suspend it with the tasks when pausing the pipeline (docs/self-hosting.md).
CREATE OR REPLACE ALERT TENDER_DB.DBT.PIPELINE_STALE
  SCHEDULE = 'USING CRON 50 7,10,13,16,19 * * * Europe/London'
  IF (EXISTS (
    SELECT
        1
    FROM
        (
            SELECT
                MAX(finished_at) AS finished_at   -- UTC, so compared with SYSDATE()
            FROM
                TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS
            WHERE
                status = 'success'
        ) AS last_load
    CROSS JOIN
        (
            SELECT
                MAX(completed_time) AS completed_time
            FROM
                TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT'))
            WHERE
                state = 'SUCCEEDED'
        ) AS last_build
    WHERE
        COALESCE(last_load.finished_at < DATEADD('hour', -4, SYSDATE()), TRUE)
        OR COALESCE(last_build.completed_time < DATEADD('hour', -4, CURRENT_TIMESTAMP()), TRUE)
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'TENDER_EMAIL',
      '<% alert_email %>',
      'Find a Tender data is out of date',
      'No successful load or dbt run in the last 4 hours. Check whether a task has suspended itself (SHOW TASKS IN DATABASE TENDER_DB), then TASK_HISTORY.'
    );

ALTER ALERT TENDER_DB.DBT.PIPELINE_STALE RESUME;

-- Run once now instead of waiting for the schedule, then check the result:
--   EXECUTE TASK TENDER_DB.DBT.RUN_DBT;
--   SELECT * FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT'))
--   ORDER BY scheduled_time DESC;
