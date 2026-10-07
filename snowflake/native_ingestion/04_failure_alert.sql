-- Email when a scheduled load fails.
-- Task error notifications cannot send email, so an alert checks the task history
-- 30 minutes after each run slot (07:30, 10:30, ... 19:30 UK time, every day).
-- Serverless (no WAREHOUSE).
-- Deployed by .github/workflows/deploy.yml, which fills in the recipient from the
-- ALERT_EMAIL secret. To run by hand:
--   snow sql -f snowflake/native_ingestion/04_failure_alert.sql -D alert_email=<you> -c tender
USE ROLE SYSADMIN;

CREATE OR REPLACE ALERT TENDER_DB.RAW.INGEST_FIND_A_TENDER_FAILED
  SCHEDULE = 'USING CRON 30 7-19/3 * * * Europe/London'
  IF (EXISTS (
    SELECT 1
    FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(
      -- since the last check; the last 12 hours on the first check
      SCHEDULED_TIME_RANGE_START => COALESCE(
        SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME(),
        DATEADD('hour', -12, SNOWFLAKE.ALERT.SCHEDULED_TIME())
      ),
      ERROR_ONLY => TRUE
    ))
    WHERE name LIKE 'INGEST_FIND_A_TENDER%'
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
      SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
        'A scheduled Find a Tender load failed. Check TASK_HISTORY and '
        || 'TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS. '
        || 'A task suspends itself after 3 failures in a row.'
      ),
      SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
        'TENDER_EMAIL',
        'Find a Tender ingest failed',
        ARRAY_CONSTRUCT('<% alert_email %>')
      )
    );

-- Alerts are created suspended
ALTER ALERT TENDER_DB.RAW.INGEST_FIND_A_TENDER_FAILED RESUME;

-- Test the email without waiting for a failure:
--   CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
--     SNOWFLAKE.NOTIFICATION.TEXT_PLAIN('Test from TENDER_DB'),
--     SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
--       'TENDER_EMAIL', 'Test', ARRAY_CONSTRUCT('<you>')));
