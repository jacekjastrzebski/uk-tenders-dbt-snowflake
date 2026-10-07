-- Requires a paid Snowflake account (trial accounts block external access).

USE ROLE SYSADMIN;

CREATE STAGE IF NOT EXISTS TENDER_DB.RAW.CODE_STAGE
  COMMENT = 'Python code for stored procedures';
