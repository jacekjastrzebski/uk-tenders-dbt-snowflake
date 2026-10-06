-- Requires a paid Snowflake account (trial accounts block external access).
-- Production alternative to running the loader on GitHub Actions.

-- Run the loader every 3 hours (00:00, 03:00, ... UTC)
USE ROLE SYSADMIN;

CREATE OR REPLACE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER
  WAREHOUSE = TENDER_WH
  SCHEDULE = 'USING CRON 0 */3 * * * UTC'
  AS
    CALL TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES();

-- Tasks are created suspended
ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER RESUME;
