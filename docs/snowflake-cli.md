# Snowflake CLI: setup and deploy

How to run the `snowflake/` scripts from the command line with [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`), the successor to SnowSQL.

## Set up a computer (once)

Install the CLI:

```bash
uv tool install snowflake-cli
```

Create a key pair for this computer (key-pair login works without a browser, also in WSL):

```bash
mkdir -p ~/.snowflake && cd ~/.snowflake
openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out key.p8
openssl rsa -in key.p8 -pubout -out key.pub
chmod 600 key.p8
```

Register the public key on your user in a Snowsight worksheet: paste `key.pub` without the BEGIN/END lines. A user has two key slots (`RSA_PUBLIC_KEY` and `RSA_PUBLIC_KEY_2`); use the one another computer is not using.

```sql
ALTER USER <user> SET RSA_PUBLIC_KEY_2 = 'MIIB...';
```

Add the connection named `tender` (the loader uses the same one), then test it:

```bash
snow connection add --no-interactive \
  --connection-name tender \
  --account <orgname>-<accountname> \
  --user <user> \
  --authenticator SNOWFLAKE_JWT \
  --private-key-file ~/.snowflake/key.p8 \
  --role SYSADMIN --warehouse TENDER_WH --database TENDER_DB --schema RAW

snow connection test -c tender
```

The account identifier is in Snowsight: account menu → View account details.

## Run a script

```bash
snow sql -f <script.sql> -c tender          # a file
snow sql -q "<statement>" -c tender         # one statement
```

Each script starts with `USE ROLE`, so it switches role itself: `01_external_access.sql` needs a user with ACCOUNTADMIN; `02`–`04` use `TENDER_INGEST`, which SYSADMIN inherits.

## Set up Snowflake (once)

```bash
snow sql -f snowflake/setup/01_database_warehouse.sql -c tender
snow sql -f snowflake/setup/02_raw_objects.sql -c tender
snow sql -f snowflake/native_ingestion/00_code_stage.sql -c tender
snow sql -f snowflake/native_ingestion/01_external_access.sql -c tender
```

Check that the procedure's Python version has the packages it needs:

```bash
snow sql -c tender -q "SELECT package_name, MAX(version) FROM INFORMATION_SCHEMA.PACKAGES
  WHERE language = 'python' AND runtime_version = '3.14'
    AND package_name IN ('requests', 'snowflake-snowpark-python') GROUP BY package_name"
```

## Deploy user for GitHub Actions

`01_external_access.sql` creates service user `TENDER_DEPLOY` with role `TENDER_INGEST` only. Give it a key pair and store the private key in GitHub:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out deploy_key.p8
PUB=$(openssl rsa -in deploy_key.p8 -pubout | grep -v '^-----' | tr -d '\n')
snow sql -c tender -q "USE ROLE ACCOUNTADMIN; ALTER USER TENDER_DEPLOY SET RSA_PUBLIC_KEY = '$PUB'"
gh secret set SNOWFLAKE_USER --body TENDER_DEPLOY
gh secret set SNOWFLAKE_PRIVATE_KEY < deploy_key.p8
rm deploy_key.p8
```

To run any `snow` command as the deploy user (e.g. to test a deploy), replace `-c tender` with a temporary connection:

```bash
-x --account <orgname>-<accountname> --user TENDER_DEPLOY --authenticator SNOWFLAKE_JWT \
   --private-key-file deploy_key.p8 --role TENDER_INGEST --database TENDER_DB --warehouse TENDER_WH
```

## Deploy the loader

Merging to `main` runs these through `.github/workflows/deploy.yml`. By hand:

```bash
snow stage copy ingestion/load_find_a_tender.py @TENDER_DB.RAW.CODE_STAGE --overwrite -c tender
snow sql -f snowflake/native_ingestion/02_ingest_procedure.sql -c tender
snow sql -f snowflake/native_ingestion/03_ingest_task.sql -c tender
snow sql -f snowflake/native_ingestion/04_failure_alert.sql -D alert_email=<you> -c tender
```

## Run and check

Run a task now instead of waiting for its schedule:

```bash
snow sql -c tender -q "EXECUTE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER"
```

Task runs (`SUCCEEDED`, `FAILED`; the newest `SCHEDULED` row is the next run):

```bash
snow sql -c tender -q "SELECT name, state, error_message, query_start_time
  FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY())
  WHERE name LIKE 'INGEST_FIND_A_TENDER%' AND state <> 'SCHEDULED'
  ORDER BY query_start_time DESC LIMIT 5"
```

Loader runs, with the time window and number of releases:

```bash
snow sql -c tender -q "SELECT run_id, window_from, window_to, releases, status, error_message
  FROM TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS ORDER BY finished_at DESC LIMIT 5"
```

## Backfill history (once)

Loads every notice since 24 February 2025, one UTC day per run, up to where the scheduled runs began ([ADR 0017](adr/0017-backfill-from-procurement-act-start.md)). About 2,000 API pages; expect roughly an hour.

The scheduled load must have succeeded at least once (see [Run and check](#run-and-check)); the backfill refuses to start otherwise.

1. Add the `run_type` column (safe to re-run):

   ```bash
   snow sql -f snowflake/setup/02_raw_objects.sql -c tender
   ```

2. Run the backfill inside Snowflake as `TENDER_INGEST`, the role that owns loading (ADR 0004). The procedure is deployed with the loader (`02_ingest_procedure.sql`). If it stops, call it again: days already loaded are skipped.

   ```bash
   snow sql -c tender -q "USE ROLE TENDER_INGEST; USE WAREHOUSE TENDER_WH;
     CALL TENDER_DB.RAW.BACKFILL_FIND_A_TENDER_RELEASES()"           # from 2025-02-24; pass a DATE for another start
   ```

   For a quick local try against a dev database, `uv run ingestion/load_find_a_tender.py --backfill` runs the same code.

3. Check for failed days and weekdays with no notices, then rebuild the models:

   ```bash
   snow sql -c tender -f snowflake/checks/backfill_coverage.sql
   uv run dbt build --project-dir dbt
   ```

## Check scripts

Read-only health checks, plus a test email for the failure alert:

```bash
snow sql -c tender -f snowflake/checks/ingest_health.sql
snow sql -c tender -f snowflake/checks/backfill_coverage.sql
snow sql -c tender -f snowflake/checks/alert_email.sql -D alert_email=<you>
```
