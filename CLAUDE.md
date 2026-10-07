# Project conventions

## Python
- Python 3.14, dependencies managed with uv (`uv add`, `uv run`).
- **Type hints are required** on every function, method and module-level constant that is not obvious. `uv run mypy` runs in strict mode over `ingestion/` and `tests/` and must pass.
- Use `@dataclass(frozen=True)` for data containers; create changed copies with `dataclasses.replace`.
- Prioritise readability: small named functions, constants at the top, a module docstring explaining what the script does.
- Tests live in `tests/`, run with `uv run pytest`, and must not need network or Snowflake (use fakes).

## SQL
- Keywords in upper case, including `AS`. Each clause keyword (`SELECT`, `FROM`, `INNER JOIN`, `ON`, `WHERE`, `GROUP BY`, `ORDER BY`, ...) on its own line, its contents on the lines below, indented 4 spaces, one column per line with trailing commas:
```sql
SELECT
    t1.col1,
    t1.col2 AS col2_alias,
    t2.col2
FROM
    table_1 AS t1
INNER JOIN
    table_2 AS t2
ON
    t1.name = t2.name
```

## Docs
- When a change adds, removes or renames dbt models, keys or relationships, update the diagrams in `docs/diagrams/` in the same PR.

## Naming
- Spell out Find a Tender as `find_a_tender` / `FIND_A_TENDER`; never abbreviate it to `fts`.

## Checks
The pre-commit hook (`uv run pre-commit install`, once per clone) and CI (`.github/workflows/ci.yml`) both run:
```bash
uv run mypy
uv run pytest
```

## Git
- Always show the proposed commit message and wait for confirmation before committing.
