# Project conventions

## Python
- Python 3.14, dependencies managed with uv (`uv add`, `uv run`).
- **Type hints are required** on every function, method and module-level constant that is not obvious. `uv run mypy` runs in strict mode over `ingestion/` and `tests/` and must pass.
- Use `@dataclass(frozen=True)` for data containers; create changed copies with `dataclasses.replace`.
- Prioritise readability: small named functions, constants at the top, a module docstring explaining what the script does.
- Tests live in `tests/`, run with `uv run pytest`, and must not need network or Snowflake (use fakes).

## Naming
- Spell out Find a Tender as `find_a_tender` / `FIND_A_TENDER`; never abbreviate it to `fts`.

## Checks
The pre-commit hook (`uv run pre-commit install`, once per clone) and CI (`.github/workflows/ci.yml`) both run:
```bash
uv run mypy
uv run pytest
```
