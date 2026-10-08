-- Use an admin role
USE ROLE SYSADMIN;

-- Create a development database and raw schema
CREATE DATABASE IF NOT EXISTS TENDER_DB;
CREATE SCHEMA IF NOT EXISTS TENDER_DB.RAW;

-- Create a virtual warehouse for compute
CREATE WAREHOUSE IF NOT EXISTS TENDER_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- No statement runs longer than 30 minutes, the dbt task's own limit (the default is 2 days)
ALTER WAREHOUSE TENDER_WH SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;

-- Cost guard (ADR 0033): at most 30 credits a month, about twice a normal month.
-- Account admins with email notifications on get an email at 75%; at 100% the
-- warehouse suspends once running queries finish, so dbt fails and its alert emails.
-- Resource monitors need ACCOUNTADMIN.
USE ROLE ACCOUNTADMIN;
CREATE RESOURCE MONITOR IF NOT EXISTS TENDER_WH_MONITOR
    WITH CREDIT_QUOTA = 30
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;
ALTER WAREHOUSE TENDER_WH SET RESOURCE_MONITOR = TENDER_WH_MONITOR;
