# Loader configuration: keep constants, or move to config?

Status: draft, not scheduled. Decision for now: keep the constants in `ingestion/load_find_a_tender.py`.

## Question

Should these move from the top of the loader into a config file?

```python
API_URL = "https://www.find-tender.service.gov.uk/api/1.0/ocdsReleasePackages"
API_DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"  # no time zone; we send UTC

RELEASES_TABLE = "RAW.FIND_A_TENDER_RELEASES"
RUNS_TABLE = "RAW.FIND_A_TENDER_INGEST_RUNS"
```

## Why not now

- **They are not settings.** The API URL is fixed; the table names must match `snowflake/setup/02_raw_objects.sql`. The values that differ between environments (database, warehouse) already come from the Snowflake connection.
- **A file complicates the Snowflake side.** The stored procedure imports one file (`IMPORTS = ('@TENDER_DB.RAW.CODE_STAGE/load_find_a_tender.py')`). A config file would also have to be uploaded by `deploy.yml`, added to `IMPORTS` and located inside the procedure's sandbox: more ways for a deploy to break.
- **Project convention.** `CLAUDE.md`: constants at the top of the module.

## When to revisit

- dev and prod need to load different tables or schemas, or
- `OVERLAP` / `FIRST_RUN_LOOKBACK` need tuning without a code change, or
- a second source is loaded by the same code.

## Plan, if one of those happens

Use **procedure arguments with defaults**, not a file: the task passes values, the code keeps its defaults, and nothing new needs uploading.

1. **Loader** (`ingestion/load_find_a_tender.py`)
   - Add a frozen dataclass with today's constants as defaults:
     ```python
     @dataclass(frozen=True)
     class Config:
         releases_table: str = "RAW.FIND_A_TENDER_RELEASES"
         runs_table: str = "RAW.FIND_A_TENDER_INGEST_RUNS"
         overlap: timedelta = timedelta(minutes=15)
     ```
   - `main(session, releases_table=..., runs_table=..., overlap_minutes=...)` builds a `Config` and passes it to `next_window`, `save_page` and `log_run`.
   - Local runs: read overrides from environment variables in the `__main__` block (as `SNOWFLAKE_CONNECTION_NAME` already is).
   - `API_URL` and `API_DATE_FORMAT` stay constants: they describe the API, not the environment.
2. **Procedure** (`snowflake/native_ingestion/02_ingest_procedure.sql`): declare the arguments with defaults, e.g. `(RELEASES_TABLE STRING DEFAULT 'RAW.FIND_A_TENDER_RELEASES', ...)`.
3. **Tasks** (`03_ingest_task.sql`): keep `CALL ...()` for defaults; pass named arguments only where an environment differs.
4. **Tests** (`tests/test_load_find_a_tender.py`): a test that a non-default `Config` writes to the given tables, using the existing `FakeSession`.

## Verification

- `uv run mypy`, `uv run pytest`.
- Deploy to Snowflake, `EXECUTE TASK`, check a new `success` row in the runs table.
- `CALL TENDER_DB.RAW.LOAD_FIND_A_TENDER_RELEASES(OVERLAP_MINUTES => 30)` uses the override.
