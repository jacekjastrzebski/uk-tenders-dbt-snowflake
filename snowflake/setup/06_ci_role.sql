-- Role and service user for the dbt build on pull requests (.github/workflows/ci.yml,
-- ADR 0030). CI builds code that isn't merged yet, so it doesn't get TENDER_TRANSFORM,
-- which owns PROD_*: TENDER_CI reads RAW and creates its own CI_PR_<n>_* schemas, nothing
-- else. Creating a schema that exists fails, and it can't replace schemas it doesn't own.
-- Needs ACCOUNTADMIN. Run after 03_transform_role.sql:
--   snow sql -f snowflake/setup/06_ci_role.sql -c tender
-- then register the user's key pair (docs/self-hosting.md, step 5).
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS TENDER_CI;
GRANT ROLE TENDER_CI TO ROLE SYSADMIN;   -- admins can manage its schemas and run the CI build locally

GRANT USAGE ON DATABASE TENDER_DB TO ROLE TENDER_CI;
GRANT USAGE ON WAREHOUSE TENDER_WH TO ROLE TENDER_CI;
GRANT CREATE SCHEMA ON DATABASE TENDER_DB TO ROLE TENDER_CI;   -- CI_PR_<n>_STAGING, _MARTS, ...

-- Read-only access to the raw data, the same as dbt in prod
GRANT USAGE ON SCHEMA TENDER_DB.RAW TO ROLE TENDER_CI;
GRANT SELECT ON TABLE TENDER_DB.RAW.FIND_A_TENDER_RELEASES TO ROLE TENDER_CI;
GRANT SELECT ON TABLE TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS TO ROLE TENDER_CI;

-- Service user for GitHub Actions: key-pair login only, no password, this role only
CREATE USER IF NOT EXISTS TENDER_CI
    TYPE = SERVICE
    DEFAULT_ROLE = TENDER_CI
    DEFAULT_WAREHOUSE = TENDER_WH
    DEFAULT_SECONDARY_ROLES = ()
    COMMENT = 'Builds dbt pull requests in GitHub Actions';
GRANT ROLE TENDER_CI TO USER TENDER_CI;

-- Then set its public key, and store the private key in the SNOWFLAKE_CI_PRIVATE_KEY
-- GitHub secret:
--   ALTER USER TENDER_CI SET RSA_PUBLIC_KEY = 'MIIB...';
