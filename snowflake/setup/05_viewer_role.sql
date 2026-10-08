-- Guest role and user: sees every schema, table, view and scheduled task,
-- and can query RAW and the prod staging, intermediate and mart schemas on
-- a warehouse of its own, capped at 1 credit a month. It can't query the
-- DEV_* schemas or change anything (ADR 0027).
-- Needs ACCOUNTADMIN. Optional; run after snowflake/dbt/00_dbt_setup.sql.
--
-- The user name and a temporary password are passed in, so neither is
-- committed; the guest must change the password at first sign-in:
--   GUEST_PASSWORD=$(uv run python -c "import secrets; print(secrets.token_urlsafe(18) + 'Aa1')")
--   snow sql -f snowflake/setup/05_viewer_role.sql -D guest_user=<NAME> -D "guest_password=$GUEST_PASSWORD" -c tender
--   echo "$GUEST_PASSWORD"
-- ('Aa1' meets Snowflake's rule of at least one upper, lower and digit.)
-- Re-running is safe: an existing user keeps its password.
-- To switch the guest off: ALTER USER <NAME> SET DISABLED = TRUE;
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS TENDER_VIEWER;
GRANT ROLE TENDER_VIEWER TO ROLE SYSADMIN;   -- admins can use and manage it

-- The guest's own warehouse, so its queries never compete with the pipeline
-- and a resource monitor can cap what they cost
CREATE WAREHOUSE IF NOT EXISTS TENDER_VIEWER_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 300;   -- no query runs longer than 5 minutes
GRANT OWNERSHIP ON WAREHOUSE TENDER_VIEWER_WH TO ROLE SYSADMIN COPY CURRENT GRANTS;

-- At most 1 credit a month: notify at 80%, stop running queries at 100%
CREATE RESOURCE MONITOR IF NOT EXISTS TENDER_VIEWER_MONITOR
    WITH CREDIT_QUOTA = 1
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;
ALTER WAREHOUSE TENDER_VIEWER_WH SET RESOURCE_MONITOR = TENDER_VIEWER_MONITOR;
GRANT USAGE ON WAREHOUSE TENDER_VIEWER_WH TO ROLE TENDER_VIEWER;

-- Every role inherits PUBLIC, and new accounts give PUBLIC warehouses and
-- compute pools; take them away so the capped warehouse is the guest's only
-- compute. Delete a line if your account doesn't have that object.
REVOKE ROLE SNOWFLAKE_LEARNING_ROLE FROM ROLE PUBLIC;
REVOKE USAGE ON WAREHOUSE "SYSTEM$STREAMLIT_NOTEBOOK_WH" FROM ROLE PUBLIC;
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU FROM ROLE PUBLIC;
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_GPU FROM ROLE PUBLIC;

-- Every schema, including those dbt creates later
GRANT USAGE ON DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;

-- REFERENCES shows a table's or view's structure, never its rows.
-- Future grants cover the tables dbt rebuilds on every run.
GRANT REFERENCES ON ALL TABLES IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT REFERENCES ON FUTURE TABLES IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT REFERENCES ON ALL VIEWS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT REFERENCES ON FUTURE VIEWS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;

-- Rows from RAW (which includes buyer contact details, ADR 0016) and from
-- the prod models. In these schemas the schema-level future grants replace
-- the database-level ones above, which is fine: SELECT shows structure too.
GRANT SELECT ON ALL TABLES IN SCHEMA TENDER_DB.RAW TO ROLE TENDER_VIEWER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TENDER_DB.RAW TO ROLE TENDER_VIEWER;
GRANT SELECT ON ALL TABLES IN SCHEMA TENDER_DB.PROD_STAGING TO ROLE TENDER_VIEWER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TENDER_DB.PROD_STAGING TO ROLE TENDER_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA TENDER_DB.PROD_INTERMEDIATE TO ROLE TENDER_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA TENDER_DB.PROD_INTERMEDIATE TO ROLE TENDER_VIEWER;
GRANT SELECT ON ALL TABLES IN SCHEMA TENDER_DB.PROD_MARTS TO ROLE TENDER_VIEWER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TENDER_DB.PROD_MARTS TO ROLE TENDER_VIEWER;

-- Task definitions and run history. Deploys recreate the tasks
-- (CREATE OR REPLACE), so the future grant puts MONITOR back each time.
GRANT MONITOR ON ALL TASKS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;
GRANT MONITOR ON FUTURE TASKS IN DATABASE TENDER_DB TO ROLE TENDER_VIEWER;

-- The guest: a person who signs in with a password, holding this role only
CREATE USER IF NOT EXISTS <% guest_user %>
    TYPE = PERSON
    PASSWORD = '<% guest_password %>'
    MUST_CHANGE_PASSWORD = TRUE
    DEFAULT_ROLE = TENDER_VIEWER
    DEFAULT_SECONDARY_ROLES = ();
ALTER USER <% guest_user %> SET DEFAULT_WAREHOUSE = TENDER_VIEWER_WH;
GRANT ROLE TENDER_VIEWER TO USER <% guest_user %>;
