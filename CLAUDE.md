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
- When a change alters what a diagram in `docs/diagrams/` shows (dbt models, keys or relationships, Snowflake objects, roles, schedules, deploy steps), update that diagram in the same PR.

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
- Commit messages read naturally, like a short note to a colleague, and list the changes as bullet points:
  - Subject line: plain English, imperative ("Add …", "Fix …"), at most 72 characters, no full stop.
  - Blank line, then one bullet (`- `) per change, saying what changed and, where useful, why. Wrap at 72 characters.
  - No jargon or filler; a one-line change can be a subject line alone.

```
Add dim_suppliers and strip lot numbers from organisation names

- Group suppliers by normalised name, the same way as buyers
- Remove framework lot numbers ("1 2 3 4", "a 1 8 b 1 8", "- Lot 1"),
  so a supplier on several lots counts once
- Flag suppliers whose name the buyer withheld (section 94)
- Record the decision to keep supplier names in ADR 0021
```
