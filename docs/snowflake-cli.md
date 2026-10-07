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

Each script starts with `USE ROLE`, so it switches role itself. `01_external_access.sql` needs a user with ACCOUNTADMIN.

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
snow sql -c tender -q "EXECUTE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER_WEEKDAYS"
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

## Check scripts

Read-only health checks, plus a test email for the failure alert:

```bash
snow sql -c tender -f snowflake/checks/ingest_health.sql
snow sql -c tender -f snowflake/checks/alert_email.sql -D alert_email=<you>
```
