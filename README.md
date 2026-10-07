# uk-tenders-dbt-snowflake

UK public procurement data from Find a Tender, loaded into Snowflake and modelled with dbt, refreshed every 3 hours from 07:00 to 19:00 UK time.

## What it is

[Find a Tender](https://www.find-tender.service.gov.uk) is the UK government's official service for publishing public procurement notices. Since the Procurement Act 2023 came into force on 24 February 2025, public bodies publish a notice at every stage of a procurement: planned, open for bids, awarded, contract signed, changed and ended.

This project turns those notices into a market tracker for digital and data services, answering:

- **What is open now?** Live tenders and their closing dates.
- **Who is buying?** Spend by buyer and sector over time.
- **Who is winning?** Suppliers, award values and market share.
- **How long does it take?** Time from tender to award to signed contract.

## How it works

```
Find a Tender API  →  Python loader  →  Snowflake (raw)  →  dbt (staging, marts)  →  Power BI
                      several times a day
                    (Snowflake tasks)
```

1. **Ingest:** a Python loader, run inside Snowflake as a stored procedure by a scheduled task, fetches notices updated since the last run and stores each API page unchanged.
2. **Transform (TO-DO):** dbt deduplicates, flattens the nested JSON and builds a star schema that follows each procurement through its notices.
3. **Report (TO-DO):** a Power BI report on top of the marts.

| Step | Status |
|---|---|
| Ingest (Python loader into Snowflake) | Done |
| Schedule (Snowflake tasks) | Done |
| Transform: dbt staging, run in Snowflake 20 minutes after each load ([ADR 0009](docs/adr/0009-run-dbt-on-a-schedule-in-snowflake.md)); marts to follow | Done |
| Event-based failure alerts for all tasks (ingest and dbt) | TO-DO |
| Report (Power BI) | TO-DO |
| Historical backfill from 24 February 2025 ([ADR 0017](docs/adr/0017-backfill-from-procurement-act-start.md)) | Ready to run, see `docs/snowflake-cli.md` |

## Repository layout

| Path | Contents |
|---|---|
| `ingestion/` | Python loader and an API exploration script |
| `snowflake/setup/` | Numbered SQL scripts that create the database, warehouse and raw tables |
| `dbt/` | dbt project: staging models (marts to follow); see `docs/dbt.md` |
| `snowflake/native_ingestion/` | Numbered SQL scripts that run the loader as a Snowflake stored procedure on a schedule (needs a paid account) |
| `snowflake/dbt/` | Setup, profile and scheduled task that run the dbt project inside Snowflake (ADR 0009) |
| `tests/` | Tests for the Python code |
| `docs/` | Procurement primer and Find a Tender API reference |

## Data and licence

Contains public sector information licensed under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/). Buyer contact details (names, emails, phone numbers) are personal data; they are not committed to this repository, and the first dbt model will drop them.

## Local development

Python dependencies are managed with [uv](https://docs.astral.sh/uv/) (Python 3.14).

```bash
uv sync                                   # create .venv and install dependencies
uv run pre-commit install                 # run checks before every commit
uv run pytest                             # run tests (no network or Snowflake needed)
uv run mypy                               # type check (strict; type hints are required)
uv run ingestion/load_find_a_tender.py    # load the last window into Snowflake
uv run ingestion/load_find_a_tender.py --backfill   # try the history load locally (prod runs it in Snowflake)
```

The loader uses the Snowflake connection named in `SNOWFLAKE_CONNECTION_NAME` (default `tender`) from `~/.snowflake/config.toml`. The connection must set `database` (e.g. `TENDER_DB`) and `warehouse` (e.g. `TENDER_WH`); the code holds no environment-specific names.

## Deploy the scheduled load

The loader runs inside Snowflake: a stored procedure imports `ingestion/load_find_a_tender.py` from a stage, and a serverless task calls it every 3 hours from 07:00 to 19:00 UK time (Europe/London). The task suspends itself after 3 failures in a row, and an alert emails you when a run fails. Calling the Find a Tender API needs external access, which trial accounts block, so this needs a paid account.

One-off setup, in a Snowflake worksheet:

1. Run the `snowflake/setup/` scripts in order, then `snowflake/native_ingestion/00_code_stage.sql`.
2. Run `01_external_access.sql` as ACCOUNTADMIN. It creates role `TENDER_INGEST`, which owns and runs the loader, and service user `TENDER_DEPLOY` for GitHub Actions; give that user a key pair (see `docs/snowflake-cli.md`).
3. Add GitHub secrets `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER` (`TENDER_DEPLOY`), `SNOWFLAKE_PRIVATE_KEY` (its private key) and `ALERT_EMAIL` (the verified email of a Snowflake user, which receives failure alerts).

After that, merging a change to the loader or to scripts `02`–`04` into `main` deploys it once the CI checks pass: `.github/workflows/deploy.yml`, called by `ci.yml`, uploads the loader and recreates the procedure, tasks and alert. To deploy by hand:

```bash
snow stage copy ingestion/load_find_a_tender.py @TENDER_DB.RAW.CODE_STAGE --overwrite -c tender
snow sql -f snowflake/native_ingestion/02_ingest_procedure.sql -c tender
snow sql -f snowflake/native_ingestion/03_ingest_task.sql -c tender
snow sql -f snowflake/native_ingestion/04_failure_alert.sql -D alert_email=<you> -c tender
```
