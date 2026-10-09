# Run your own copy

Step by step from a fork to a scheduled pipeline on your own Snowflake account and GitHub, with the Power BI report on top. How the parts fit together: [architecture.md](architecture.md).

| Step | Where | Takes about |
|---|---|---|
| [1. Prerequisites and cost](#1-prerequisites-and-cost) | | |
| [2. Fork and clone](#2-fork-and-clone) | GitHub, your computer | 10 min |
| [3. Snowflake CLI and your key pair](#3-snowflake-cli-and-your-key-pair) | Your computer, Snowsight | 10 min |
| [4. Run the setup scripts](#4-run-the-setup-scripts) | Your computer → Snowflake | 5 min |
| [5. Deploy and CI users, GitHub secrets](#5-deploy-and-ci-users-github-secrets) | Your computer → Snowflake, GitHub | 15 min |
| [6. First deploy](#6-first-deploy) | GitHub Actions → Snowflake | 5 min |
| [7. First load and backfill](#7-first-load-and-backfill) | Snowflake | 1 min, backfill about an hour |
| [8. First dbt build](#8-first-dbt-build) | Snowflake | 2 min |
| [9. Check](#9-check) | Your computer → Snowflake | 2 min |
| [10. Power BI](#10-power-bi) | Snowflake, Windows | 30 min |

## 1. Prerequisites and cost

| You need | Why | Cost |
|---|---|---|
| Snowflake account, **paid** (Standard edition is enough), and a user with `ACCOUNTADMIN` | The loader calls the API from inside Snowflake (external access), which trial accounts block; some setup scripts need `ACCOUNTADMIN` | See below |
| GitHub account and the [GitHub CLI](https://cli.github.com) (`gh auth login`) | Fork, CI, deploys and secrets | Free for public repos |
| Linux, macOS or WSL with [uv](https://docs.astral.sh/uv/), git and OpenSSL | Run tests, the Snowflake CLI and dbt locally | Free |
| Windows 10 or 11 with [Power BI Desktop](https://www.microsoft.com/power-bi/desktop) | Open and refresh the report | Free |
| Power BI Pro (or a Fabric capacity) | Only to publish the report to Power BI Service and share it | Per user licence |

**Snowflake cost, roughly.** Typical runs: load about 25 s on serverless SMALL compute, dbt about 70 s on the X-SMALL `TENDER_WH` (billed at least 60 s, then suspends after 60 s idle), 5 times a day. With a Power BI refresh after each build, expect around 10–15 credits a month; storage is a few GB. A resource monitor stops `TENDER_WH` at 30 credits a month (step 4). Check actual use in Snowsight → Admin → Cost management after the first week.

**Trial account?** External access is blocked, so the loader can't run inside Snowflake. You can still try the rest from your computer: in step 4 run only the four `snowflake/setup/` scripts, skip steps 5–8, then load with `uv run ingestion/load_find_a_tender.py` and build with dbt against `dev` ([dbt.md](dbt.md)).

## 2. Fork and clone

1. Fork the repository on GitHub, then enable workflows in your fork: Actions tab → *I understand my workflows, go ahead and enable them*.
2. Clone, point `gh` at your fork (otherwise `gh` commands may act on the original repository), and install:

   ```bash
   git clone https://github.com/<you>/uk-tenders-dbt-snowflake.git
   cd uk-tenders-dbt-snowflake
   gh repo set-default <you>/uk-tenders-dbt-snowflake
   uv sync                    # Python 3.14 and dependencies
   uv sync --group dbt        # dbt-core and dbt-snowflake 1.12
   uv run pre-commit install  # checks before every commit
   uv run pytest && uv run mypy
   ```

Don't push to `main` yet: every push to `main` runs the deploy, which fails until steps 4 and 5 are done.

## 3. Snowflake CLI and your key pair

Follow [snowflake-cli.md → Set up a computer](snowflake-cli.md#set-up-a-computer-once): install `snow`, create a key pair, register the public key on your Snowflake user and add a connection named `tender` with role `SYSADMIN`. Your account identifier (`<orgname>-<accountname>`) is in Snowsight → account menu → View account details.

```bash
snow connection test -c tender
```

The connection names `TENDER_DB` and `TENDER_WH`, which step 4 creates; if the test complains that they don't exist, carry on.

## 4. Run the setup scripts

Two scripts grant roles to the author's user, `JACEKJ`. Find your user name, then put it in both scripts (this `sed` works on Linux and macOS):

```bash
snow sql -c tender -q "SELECT CURRENT_USER()"
sed -i.bak 's/TO USER JACEKJ/TO USER <YOUR_USER>/' snowflake/setup/03_transform_role.sql snowflake/setup/04_reporting_role.sql
rm snowflake/setup/*.bak
```

Then run them in this order (each script switches to the role it needs):

```bash
snow sql -f snowflake/setup/01_database_warehouse.sql -c tender
snow sql -f snowflake/setup/02_raw_objects.sql -c tender
snow sql -f snowflake/setup/03_transform_role.sql -c tender
snow sql -f snowflake/setup/04_reporting_role.sql -c tender
snow sql -f snowflake/setup/06_ci_role.sql -c tender
snow sql -f snowflake/native_ingestion/00_code_stage.sql -c tender
snow sql -f snowflake/native_ingestion/01_external_access.sql -c tender
snow sql -f snowflake/dbt/00_dbt_setup.sql -c tender
```

| Script | Runs as | Creates |
|---|---|---|
| `setup/01_database_warehouse.sql` | SYSADMIN, then ACCOUNTADMIN | Database `TENDER_DB`, schema `RAW`, warehouse `TENDER_WH` (X-SMALL, auto-suspend 60 s, statements stop after 30 minutes), and resource monitor `TENDER_WH_MONITOR`: 30 credits a month, email at 75% (to account admins with email notifications on), suspend at 100% |
| `setup/02_raw_objects.sql` | SYSADMIN | Raw tables `FIND_A_TENDER_RELEASES`, `FIND_A_TENDER_INGEST_RUNS` |
| `setup/03_transform_role.sql` | ACCOUNTADMIN | Role `TENDER_TRANSFORM` (dbt): reads `RAW`, creates its own schemas. Also an empty schema `PROD`, which the prod dbt profile needs; models go to `PROD_STAGING`, `PROD_MARTS`, ... |
| `setup/04_reporting_role.sql` | ACCOUNTADMIN | Role `TENDER_REPORTER` (Power BI): reads `PROD_MARTS`, `DEV_MARTS` |
| `setup/06_ci_role.sql` | ACCOUNTADMIN | Role and service user `TENDER_CI`, which builds dbt pull requests: reads `RAW`, creates its own `CI_PR_*` schemas |
| `setup/05_viewer_role.sql` (optional) | ACCOUNTADMIN | Role `TENDER_VIEWER` and a guest user who can browse everything and query `RAW` and the prod schemas on warehouse `TENDER_VIEWER_WH`, capped at 1 credit a month; run it last, with the commands in its header |
| `native_ingestion/00_code_stage.sql` | SYSADMIN | Stage `RAW.CODE_STAGE` for the loader's Python file |
| `native_ingestion/01_external_access.sql` | ACCOUNTADMIN | Network rule and integration for the API host, email integration `TENDER_EMAIL`, role `TENDER_INGEST`, service user `TENDER_DEPLOY` |
| `dbt/00_dbt_setup.sql` | ACCOUNTADMIN | Schema `DBT` for the dbt project object, task and alert; grants `TENDER_TRANSFORM` to `TENDER_DEPLOY` |

Roles and what each may touch: [security.md](diagrams/security.md#roles-and-access).

## 5. Deploy and CI users, GitHub secrets

GitHub Actions signs in to Snowflake as two service users, each with a key pair ([ADR 0033](adr/0033-pipeline-safeguards.md)):
- `TENDER_DEPLOY` deploys from `main`. Its secrets live in the GitHub environment `production`, which only `main` can use, so pull request workflows can't read them.
- `TENDER_CI` builds dbt pull requests into throwaway schemas, and can't touch prod.

Create the environment, then a key pair per user: register each public key in Snowflake and store each private key as a secret ([snowflake-cli.md → Deploy user](snowflake-cli.md#deploy-user-for-github-actions)):

```bash
gh api -X PUT "repos/{owner}/{repo}/environments/production" --input - <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
JSON
gh api -X POST "repos/{owner}/{repo}/environments/production/deployment-branch-policies" -f name=main

openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out deploy_key.p8
PUB=$(openssl rsa -in deploy_key.p8 -pubout | grep -v '^-----' | tr -d '\n')
snow sql -c tender -q "USE ROLE ACCOUNTADMIN; ALTER USER TENDER_DEPLOY SET RSA_PUBLIC_KEY = '$PUB'"

openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out ci_key.p8
PUB=$(openssl rsa -in ci_key.p8 -pubout | grep -v '^-----' | tr -d '\n')
snow sql -c tender -q "USE ROLE ACCOUNTADMIN; ALTER USER TENDER_CI SET RSA_PUBLIC_KEY = '$PUB'"

gh secret set SNOWFLAKE_ACCOUNT --body <orgname>-<accountname>   # both workflows use it
gh secret set SNOWFLAKE_CI_PRIVATE_KEY < ci_key.p8
gh secret set SNOWFLAKE_USER --env production --body TENDER_DEPLOY
gh secret set SNOWFLAKE_PRIVATE_KEY --env production < deploy_key.p8
gh secret set ALERT_EMAIL --env production --body <you@example.com>
rm deploy_key.p8 ci_key.p8
```

Then protect `main`, so a pull request merges only when both CI jobs pass, for you too:

```bash
gh api -X PUT "repos/{owner}/{repo}/branches/main/protection" --input - <<'JSON'
{"required_status_checks": {"strict": true, "contexts": ["checks", "dbt"]},
 "enforce_admins": true,
 "required_pull_request_reviews": {"required_approving_review_count": 0},
 "restrictions": null}
JSON
```

`ALERT_EMAIL` must be the **verified** email address of a user in your Snowflake account (Snowsight → your profile → verify email); Snowflake only emails verified addresses. Test it once:

```bash
snow sql -c tender -f snowflake/checks/alert_email.sql -D alert_email=<you@example.com>
```

## 6. First deploy

Run the Deploy workflow by hand; a manual run deploys everything (loader, procedures, ingest task and alert, dbt project, dbt task and alerts, Power BI refresh alert) and tags the commit `deployed`:

```bash
gh workflow run deploy.yml --ref main
gh run watch
```

The deploy also creates the Power BI refresh alert, which emails when nothing has read the marts by 90 minutes after a build. Until Power BI is set up (step 10), suspend it:

```bash
snow sql -c tender -q "ALTER ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED SUSPEND"
```

The tasks are now scheduled: loads at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time, dbt 20 minutes later. From now on, merging to `main` deploys only what changed since the `deployed` tag, after the CI checks pass ([flows.md → Change to production](diagrams/flows.md#change-to-production)).

A good first change: point the loader's `USER_AGENT` (`ingestion/load_find_a_tender.py`) at your fork, so the API's operators can see who is calling, and push it to `main`. The deploy uploads the new loader.

## 7. First load and backfill

Run the first load now rather than waiting for the schedule, then check it:

```bash
snow sql -c tender -q "EXECUTE TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER"
snow sql -c tender -f snowflake/checks/ingest_health.sql
```

That loads the last 3 hours, and counts as the successful scheduled load the backfill needs. To load the history since the Procurement Act started (24 February 2025, about 2,000 API pages, roughly an hour), follow [snowflake-cli.md → Backfill history](snowflake-cli.md#backfill-history-once), but skip the `uv run dbt build` line at its end: step 8 builds prod. Check the backfill with `snowflake/checks/backfill_coverage.sql`.

## 8. First dbt build

Build the prod schemas now rather than waiting for the next scheduled run:

```bash
snow sql -c tender -q "EXECUTE TASK TENDER_DB.DBT.RUN_DBT"
```

Watch it in Snowsight → Monitoring → dbt projects. For development, set up `~/.dbt/profiles.yml` and build into your `DEV_*` schemas from your computer ([dbt.md → Set up](dbt.md#set-up-once)).

## 9. Check

```bash
snow sql -c tender -q "
SELECT
    name,
    state,
    error_message,
    query_start_time
FROM
    TABLE(TENDER_DB.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE
    name IN ('INGEST_FIND_A_TENDER', 'RUN_DBT')
    AND state <> 'SCHEDULED'
ORDER BY
    query_start_time DESC
LIMIT 10"

snow sql -c tender -q "
SELECT
    table_name,
    row_count
FROM
    TENDER_DB.INFORMATION_SCHEMA.TABLES
WHERE
    table_schema = 'PROD_MARTS'
ORDER BY
    table_name"
```

Seven mart tables with rows, and `SUCCEEDED` for both tasks, means the pipeline works end to end.

## 10. Power BI

Follow [powerbi.md → Set up your own](powerbi.md#set-up-your-own): a Snowflake user `TENDER_POWERBI` that holds only `TENDER_REPORTER` and signs in with a key pair, then Power BI Desktop, connecting and refreshing, and optionally publishing with a scheduled refresh after each dbt build.

Once the scheduled refresh runs, turn the refresh alert back on (it was suspended in step 6); without a scheduled refresh, leave it off:

```bash
snow sql -c tender -q "ALTER ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED RESUME"
```

## Run it

| Task | How |
|---|---|
| See task runs and errors | The `TASK_HISTORY` query in step 9, or Snowsight → Monitoring → Task history |
| See dbt output | Snowsight → Monitoring → dbt projects |
| Loader runs and windows | `snowflake/checks/ingest_health.sql` |
| A task suspended itself (3 failures in a row) | Fix the cause, then `ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER RESUME` (or `TENDER_DB.DBT.RUN_DBT`); a redeploy also resumes it |
| Pause everything to save credits | Suspend both tasks and the alerts (below); a manual Deploy run resumes them all |
| `TENDER_WH` stopped: monthly credit cap reached | Check what used it (Snowsight → Admin → Cost management), then as ACCOUNTADMIN `ALTER RESOURCE MONITOR TENDER_WH_MONITOR SET CREDIT_QUOTA = <more>`, or wait for the next month |
| A deploy failed or was cancelled | The next merge or a manual Deploy run deploys everything changed since the `deployed` tag |
| Upgrade dbt | Move the pins in `pyproject.toml` and `deploy.yml` together ([dbt.md → Runs in Snowflake](dbt.md#runs-in-snowflake)) |
| Change the schedule | Edit the cron in `03_ingest_task.sql`, `04_failure_alert.sql` and `01_run_dbt_task.sql`. If the gap between runs changes from 3 hours, change the ingest alert's 3-hour look-back, the stale-data alert's 4 hours and the freshness thresholds in `_find_a_tender__sources.yml` to match. Merge to `main` |

Pause everything:

```bash
snow sql -c tender -q "ALTER TASK TENDER_DB.RAW.INGEST_FIND_A_TENDER SUSPEND;
  ALTER ALERT TENDER_DB.RAW.INGEST_FIND_A_TENDER_FAILED SUSPEND;
  ALTER TASK TENDER_DB.DBT.RUN_DBT SUSPEND;
  ALTER ALERT TENDER_DB.DBT.RUN_DBT_FAILED SUSPEND;
  ALTER ALERT TENDER_DB.DBT.PIPELINE_STALE SUSPEND;
  ALTER ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED SUSPEND"
```

## Remove it

Replace `<GUEST_USER>` with the guest's user name from step 4, or delete that line if you didn't create one. No need to suspend anything first: dropping the database drops its tasks, alerts, procedures and stage. Drop the API integration before the database, because it refers to the network rule in `RAW`.

```bash
snow sql -c tender -q "USE ROLE ACCOUNTADMIN;
  DROP INTEGRATION IF EXISTS FIND_A_TENDER_API_ACCESS;
  DROP INTEGRATION IF EXISTS TENDER_EMAIL;
  DROP DATABASE IF EXISTS TENDER_DB;
  DROP WAREHOUSE IF EXISTS TENDER_WH;
  DROP WAREHOUSE IF EXISTS TENDER_VIEWER_WH;
  DROP RESOURCE MONITOR IF EXISTS TENDER_WH_MONITOR;
  DROP RESOURCE MONITOR IF EXISTS TENDER_VIEWER_MONITOR;
  DROP USER IF EXISTS TENDER_DEPLOY;
  DROP USER IF EXISTS TENDER_POWERBI;
  DROP USER IF EXISTS TENDER_CI;
  DROP USER IF EXISTS <GUEST_USER>;
  DROP ROLE IF EXISTS TENDER_INGEST;
  DROP ROLE IF EXISTS TENDER_TRANSFORM;
  DROP ROLE IF EXISTS TENDER_REPORTER;
  DROP ROLE IF EXISTS TENDER_CI;
  DROP ROLE IF EXISTS TENDER_VIEWER"
```

Then delete the GitHub secrets (`gh secret delete <name>`), the environment (`gh api -X DELETE "repos/{owner}/{repo}/environments/production"`) and the published report, if any.
