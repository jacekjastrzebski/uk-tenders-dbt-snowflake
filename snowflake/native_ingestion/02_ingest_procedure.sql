-- Requires a paid Snowflake account (trial accounts block external access).

-- Stored procedure that runs ingestion/load_find_a_tender.py.
-- Deployed by .github/workflows/deploy.yml on merge to main, which first uploads the file:
--   snow stage copy ingestion/load_find_a_tender.py @TENDER_DB.RAW.CODE_STAGE --overwrite -c tender
USE ROLE SYSADMIN;

CREATE OR REPLACE PROCEDURE TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.14'
  PACKAGES = ('snowflake-snowpark-python', 'requests')
  IMPORTS = ('@TENDER_DB.RAW.CODE_STAGE/load_find_a_tender.py')
  HANDLER = 'load_find_a_tender.main'
  EXTERNAL_ACCESS_INTEGRATIONS = (FIND_A_TENDER_API_ACCESS)
  EXECUTE AS OWNER;
