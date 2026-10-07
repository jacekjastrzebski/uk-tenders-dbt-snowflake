-- Stored procedures that run ingestion/load_find_a_tender.py.
-- Deployed by .github/workflows/deploy.yml on merge to main, which first uploads the file:
--   snow stage copy ingestion/load_find_a_tender.py @TENDER_DB.RAW.CODE_STAGE --overwrite -c tender
USE ROLE TENDER_INGEST;

-- Scheduled load, called by the task in 03_ingest_task.sql
CREATE OR REPLACE PROCEDURE TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.14'
  PACKAGES = ('snowflake-snowpark-python', 'requests', 'tzdata')  -- tzdata: UK time for API dates
  IMPORTS = ('@TENDER_DB.RAW.CODE_STAGE/load_find_a_tender.py')
  HANDLER = 'load_find_a_tender.main'
  EXTERNAL_ACCESS_INTEGRATIONS = (FIND_A_TENDER_API_ACCESS)
  EXECUTE AS OWNER;

-- One-off history load (ADR 0017), called by hand; runs on the caller's warehouse:
--   CALL TENDER_DB.RAW.BACKFILL_FIND_A_TENDER_RELEASES();               -- from 2025-02-24
--   CALL TENDER_DB.RAW.BACKFILL_FIND_A_TENDER_RELEASES('2026-01-01');   -- from another date
CREATE OR REPLACE PROCEDURE TENDER_DB.RAW.BACKFILL_FIND_A_TENDER_RELEASES(START_DATE DATE DEFAULT '2025-02-24'::DATE)
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.14'
  PACKAGES = ('snowflake-snowpark-python', 'requests', 'tzdata')  -- tzdata: UK time for API dates
  IMPORTS = ('@TENDER_DB.RAW.CODE_STAGE/load_find_a_tender.py')
  HANDLER = 'load_find_a_tender.backfill'
  EXTERNAL_ACCESS_INTEGRATIONS = (FIND_A_TENDER_API_ACCESS)
  EXECUTE AS OWNER;
