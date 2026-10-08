-- Browse-only role and user for a guest: sees schemas, tables, columns,
-- views and the scheduled tasks, but cannot read rows, run queries or
-- change anything. It has no warehouse, so it costs nothing (ADR 0027).
-- Needs ACCOUNTADMIN. Optional; run after snowflake/dbt/00_dbt_setup.sql.
--
-- The user name and a temporary password are passed in, so neither is
-- committed; the guest must change the password at first sign-in:
--   GUEST_PASSWORD=$(uv run python -c "import secrets; print(secrets.token_urlsafe(18) + 'Aa1')")
--   snow sql -f snowflake/setup/05_viewer_role.sql -D guest_user=<NAME> -D "guest_password=$GUEST_PASSWORD" -c tender
--   echo "$GUEST_PASSWORD"
-- ('Aa1' meets Snowflake's rule of at least one upper, lower and digit.)
-- To switch the guest off: ALTER USER <NAME> SET DISABLED = TRUE;
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS TENDER_VIEWER;
GRANT ROLE TENDER_VIEWER TO ROLE SYSADMIN;   -- admins can use and manage it

-- No USAGE on any warehouse: that is what keeps the guest from running queries

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
GRANT ROLE TENDER_VIEWER TO USER <% guest_user %>;
