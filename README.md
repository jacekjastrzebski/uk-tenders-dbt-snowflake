# uk-tenders-dbt-snowflake

UK public procurement data from Find a Tender, loaded into Snowflake and modelled with dbt, refreshed every 3 hours.

## Local development

Python dependencies are managed with [uv](https://docs.astral.sh/uv/) (Python 3.14).

```bash
uv sync                                   # create .venv and install dependencies
uv run pre-commit install                 # run checks before every commit
uv run pytest                             # run tests (no network or Snowflake needed)
uv run mypy                               # type check (strict; type hints are required)
uv run ingestion/load_find_a_tender.py    # load the last window into Snowflake
```

The loader uses the Snowflake connection named in `SNOWFLAKE_CONNECTION_NAME` (default `tender`) from `~/.snowflake/config.toml`.
