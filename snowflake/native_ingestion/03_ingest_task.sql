-- Run the loader every 3 hours from 07:00 to 19:00 UK time, every day
-- (Europe/London, so it follows BST).
-- Each run fetches everything since the last successful run, so gaps lose no data.
-- Serverless (no WAREHOUSE), fixed at SMALL compute; billed only for the run time.
-- Deployed by .github/workflows/deploy.yml on merge to main.
USE ROLE TENDER_INGEST;

-- Earlier versions had separate weekday and weekend tasks
DROP TASK IF EXISTS TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKDAYS;
DROP TASK IF EXISTS TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKENDS;

CREATE OR REPLACE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER
  SCHEDULE = 'USING CRON 0 7,10,13,16,19 * * * Europe/London'
  USER_TASK_TIMEOUT_MS = 900000          -- stop a stuck run after 15 minutes
  ALLOW_OVERLAPPING_EXECUTION = FALSE    -- never run two loads at once
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3    -- stop retrying a broken load
  SERVERLESS_TASK_MIN_STATEMENT_SIZE = 'SMALL'
  SERVERLESS_TASK_MAX_STATEMENT_SIZE = 'SMALL'
  AS
    CALL TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES();

-- Tasks are created suspended
ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER RESUME;

-- Run once now instead of waiting for the schedule, then check the result:
--   EXECUTE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER;
--   SELECT * FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'INGEST_FIND_A_TENDER'))
--   ORDER BY scheduled_time DESC;
