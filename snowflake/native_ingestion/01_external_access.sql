-- Allow Snowflake to call the Find a Tender API, run serverless tasks and alerts,
-- and send failure emails.
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

-- Failure emails. The recipient is set in 04_failure_alert.sql from the
-- ALERT_EMAIL GitHub secret; it must be the verified email of a user in this account.
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS TENDER_EMAIL
  TYPE = EMAIL
  ENABLED = TRUE;

-- SYSADMIN owns the procedure, the tasks and the alert
GRANT USAGE ON INTEGRATION FIND_A_TENDER_API_ACCESS TO ROLE SYSADMIN;
GRANT USAGE ON INTEGRATION TENDER_EMAIL TO ROLE SYSADMIN;
GRANT EXECUTE TASK, EXECUTE MANAGED TASK ON ACCOUNT TO ROLE SYSADMIN;
GRANT EXECUTE ALERT, EXECUTE MANAGED ALERT ON ACCOUNT TO ROLE SYSADMIN;
