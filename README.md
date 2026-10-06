# uk-tenders-dbt-snowflake

UK public procurement data from Find a Tender, loaded into Snowflake and modelled with dbt, refreshed every 3 hours.

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
                      every 3 hours
```

1. **Ingest:** a Python loader fetches notices updated since the last run and stores each API page unchanged in Snowflake.
2. **Transform (TO-DO):** dbt deduplicates, flattens the nested JSON and builds a star schema that follows each procurement through its notices.
3. **Report (TO-DO):** a Power BI report on top of the marts.

| Step | Status |
|---|---|
| Ingest (Python loader into Snowflake) | Done |
| Schedule every 3 hours (GitHub Actions) | TO-DO |
| Transform (dbt) | TO-DO |
| Report (Power BI) | TO-DO |

## Repository layout

| Path | Contents |
|---|---|
| `ingestion/` | Python loader and an API exploration script |
| `snowflake/setup/` | Numbered SQL scripts that create the database, warehouse and raw tables |
| `snowflake/native_ingestion/` | Alternative: the loader as a Snowflake stored procedure and task (needs a paid account) |
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
```

The loader uses the Snowflake connection named in `SNOWFLAKE_CONNECTION_NAME` (default `tender`) from `~/.snowflake/config.toml`. The connection must set `database` (e.g. `TENDER_DB`) and `warehouse` (e.g. `TENDER_WH`); the code holds no environment-specific names.
