-- Requires a paid Snowflake account (trial accounts block external access).
-- Production alternative to running the loader on GitHub Actions.

-- Allow Snowflake to call the Find a Tender API.
-- Integrations and task privileges are account-level, so this needs ACCOUNTADMIN.
USE ROLE ACCOUNTADMIN;

-- Outbound traffic is allowed to this host only
CREATE NETWORK RULE IF NOT EXISTS TENDER_DB.RAW.FIND_A_TENDER_API_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('www.find-tender.service.gov.uk');

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS FIND_A_TENDER_API_ACCESS
  ALLOWED_NETWORK_RULES = (TENDER_DB.RAW.FIND_A_TENDER_API_RULE)
  ENABLED = TRUE;

-- SYSADMIN owns the procedure and the task
GRANT USAGE ON INTEGRATION FIND_A_TENDER_API_ACCESS TO ROLE SYSADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;
