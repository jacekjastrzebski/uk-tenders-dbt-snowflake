-- Run dbt in Snowflake 20 minutes after each load (ADR 0009), and email if it fails.
-- Loads run at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time and take about a minute.
-- The dbt project object TENDER_DB.DBT.UK_TENDERS is deployed by .github/workflows/deploy.yml
-- (snow dbt deploy); this script is deployed there too, filling in the alert recipient. By hand:
--   snow sql -f snowflake/dbt/01_run_dbt_task.sql -D alert_email=<you> -c tender
USE ROLE TENDER_TRANSFORM;

-- dbt projects can't run in serverless tasks, and the task must sit in the project's schema.
-- Freshness first: raw data older than 26 hours fails the task before anything is rebuilt.
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

-- Email when a dbt run failed since the previous check (checks are 3 hours apart).
-- Separate from the ingest alert: that one runs as TENDER_INGEST, which can't see this task.
CREATE OR REPLACE ALERT TENDER_DB.DBT.RUN_DBT_FAILED
  SCHEDULE = 'USING CRON 50 7,10,13,16,19 * * * Europe/London'
  IF (EXISTS (
    SELECT 1
    FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT', ERROR_ONLY => TRUE))
    WHERE scheduled_time > DATEADD('hour', -3, CURRENT_TIMESTAMP())
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

-- Run once now instead of waiting for the schedule, then check the result:
--   EXECUTE TASK TENDER_DB.DBT.RUN_DBT;
--   SELECT * FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'RUN_DBT'))
--   ORDER BY scheduled_time DESC;
