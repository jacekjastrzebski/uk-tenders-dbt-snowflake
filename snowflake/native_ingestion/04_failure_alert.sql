-- Email when a scheduled load fails.
-- Checks 30 minutes after each run slot whether any ingest run failed since the
-- previous check (checks are 3 hours apart, so each failure is emailed once).
-- Deployed by .github/workflows/deploy.yml, which fills in the recipient from the
-- ALERT_EMAIL secret. To run by hand:
--   snow sql -f snowflake/native_ingestion/04_failure_alert.sql -D alert_email=<you> -c tender
-- Test the email with snowflake/checks/alert_email.sql.
USE ROLE TENDER_INGEST;

CREATE OR REPLACE ALERT TENDER_DB.RAW.INGEST_FIND_A_TENDER_FAILED
  SCHEDULE = 'USING CRON 30 7,10,13,16,19 * * * Europe/London'
  IF (EXISTS (
    SELECT 1
    FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(ERROR_ONLY => TRUE))
    WHERE name LIKE 'INGEST_FIND_A_TENDER%'
      AND scheduled_time > DATEADD('hour', -3, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'TENDER_EMAIL',
      '<% alert_email %>',
      'Find a Tender ingest failed',
      'A scheduled load failed. Check TASK_HISTORY and TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS.'
    );

-- Alerts are created suspended
ALTER ALERT TENDER_DB.RAW.INGEST_FIND_A_TENDER_FAILED RESUME;
