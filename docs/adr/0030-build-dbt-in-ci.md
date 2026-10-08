# 0030. Build and test dbt on pull requests

Status: Accepted (2026-10-08); CI user and role changed to `TENDER_CI` by [0033](0033-pipeline-safeguards.md)

## Context
CI ran pre-commit, mypy and pytest only. A broken model, a bad `ref()` or a failing data test was found only after merging, when the prod build in Snowflake failed and the alert emailed ([ADR 0009](0009-run-dbt-on-a-schedule-in-snowflake.md)).

## Decision
- A `dbt` job in `ci.yml` parses the project on every pull request and push (no Snowflake needed: the CI profile in `.github/dbt/` falls back to placeholder credentials).
- On pull requests that change `dbt/`, it also runs `dbt build` (all models, seeds and data tests on the full raw data) into temporary schemas `CI_PR_<number>_STAGING`, `_INTERMEDIATE` and `_MARTS`, as `TENDER_DEPLOY` with role `TENDER_TRANSFORM`, then drops them with the macro `drop_ci_schemas` (only `CI_` prefixes accepted), even when the build fails.
- Deploy waits for both CI jobs.

## Consequences
- Mistakes in dbt show up on the pull request instead of in prod.
- Each dbt pull request run costs about a minute of the X-Small warehouse.
- Pull requests from forks get no secrets: they are parsed but not built.
- Source freshness isn't checked in CI; it stays part of the scheduled prod run.
