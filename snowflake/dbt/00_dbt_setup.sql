-- One-off setup for running dbt inside Snowflake (ADR 0009). Needs ACCOUNTADMIN.
-- Run after snowflake/setup/03_transform_role.sql and snowflake/native_ingestion/01_external_access.sql
-- (it grants on the TENDER_EMAIL integration and the TENDER_DEPLOY user created there):
--   snow sql -f snowflake/dbt/00_dbt_setup.sql -c tender
USE ROLE ACCOUNTADMIN;

-- Schema for the dbt project object, its task and alert; the task must sit in the project's schema
CREATE SCHEMA IF NOT EXISTS TENDER_DB.DBT;
GRANT OWNERSHIP ON SCHEMA TENDER_DB.DBT TO ROLE TENDER_TRANSFORM COPY CURRENT GRANTS;

-- Run the scheduled task and its failure alert (serverless alert, warehouse task)
GRANT EXECUTE TASK ON ACCOUNT TO ROLE TENDER_TRANSFORM;
GRANT EXECUTE ALERT, EXECUTE MANAGED ALERT ON ACCOUNT TO ROLE TENDER_TRANSFORM;
GRANT USAGE ON INTEGRATION TENDER_EMAIL TO ROLE TENDER_TRANSFORM;

-- GitHub Actions deploys the dbt project, task and alert as TENDER_TRANSFORM
GRANT ROLE TENDER_TRANSFORM TO USER TENDER_DEPLOY;
