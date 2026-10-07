-- Run the loader during UK working hours (Europe/London, so it follows BST):
--   weekdays: every 3 hours from 07:00 to 19:00
--   weekends: 07:00 and 19:00
-- A task has one schedule, so each pattern gets its own task.
-- Each run fetches everything since the last successful run, so gaps lose no data.
-- Serverless (no WAREHOUSE), fixed at SMALL compute; billed only for the run time.
-- Deployed by .github/workflows/deploy.yml on merge to main.
USE ROLE TENDER_INGEST;

CREATE OR REPLACE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKDAYS
  SCHEDULE = 'USING CRON 0 7,10,13,16,19 * * MON-FRI Europe/London'
  USER_TASK_TIMEOUT_MS = 900000          -- stop a stuck run after 15 minutes
  ALLOW_OVERLAPPING_EXECUTION = FALSE    -- never run two loads at once
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3    -- stop retrying a broken load
  SERVERLESS_TASK_MIN_STATEMENT_SIZE = 'SMALL'
  SERVERLESS_TASK_MAX_STATEMENT_SIZE = 'SMALL'
  AS
    CALL TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES();

CREATE OR REPLACE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKENDS
  SCHEDULE = 'USING CRON 0 7,19 * * SAT,SUN Europe/London'
  USER_TASK_TIMEOUT_MS = 900000
  ALLOW_OVERLAPPING_EXECUTION = FALSE
  SUSPEND_TASK_AFTER_NUM_FAILURES = 3
  SERVERLESS_TASK_MIN_STATEMENT_SIZE = 'SMALL'
  SERVERLESS_TASK_MAX_STATEMENT_SIZE = 'SMALL'
  AS
    CALL TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES();

-- Tasks are created suspended
ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKDAYS RESUME;
ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKENDS RESUME;

-- Run once now instead of waiting for the schedule, then check the result:
--   EXECUTE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKDAYS;
--   SELECT * FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY())
--   WHERE name LIKE 'INGEST_FIND_A_TENDER%'
--   ORDER BY scheduled_time DESC;
