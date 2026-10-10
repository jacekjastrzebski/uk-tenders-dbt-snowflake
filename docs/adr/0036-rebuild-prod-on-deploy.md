# 0036. Rebuild prod when dbt changes are deployed

Status: Accepted (2026-10-10). Adds to [0009](0009-run-dbt-on-a-schedule-in-snowflake.md).

## Context
Merging a dbt change deployed a new version of the dbt project, but prod was only rebuilt at the next scheduled run, up to 12 hours later overnight. Until then the deployed code and the prod tables didn't match, so a report change that needed new columns had to wait, or someone ran the task by hand. A broken build also only showed up as an email after the scheduled run.

## Decision
After "Deploy dbt project", `deploy.yml` runs `EXECUTE TASK TENDER_DB.DBT.RUN_DBT` (the same task as the schedule: freshness, build, tests) and polls `TASK_HISTORY` until the run ends. A failed or cancelled run fails the deploy. If a scheduled run is already going, the new run is skipped and the deploy passes: that run builds with the new project.

## Consequences
- A merged dbt change is in prod about two minutes after the deploy.
- A failing build shows on the merge in GitHub, as well as by email.
- About one extra minute of `TENDER_WH` per dbt merge; the deploy job can take up to 20 minutes.
