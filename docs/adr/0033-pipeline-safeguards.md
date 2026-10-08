# 0033. Pipeline safeguards: CI role, deploy catch-up, stale-data alert, cost cap

Status: Accepted (2026-10-08). Changes what a deploy compares with ([0005](0005-deploy-only-changed-objects.md)), confirms how dbt failures behave ([0009](0009-run-dbt-on-a-schedule-in-snowflake.md)) and replaces the CI role ([0030](0030-build-dbt-in-ci.md)).

## Context
A review of the pipeline in October 2026 found ways it could break prod, fail without anyone hearing, or cost more than expected:
- CI built unmerged dbt code as `TENDER_DEPLOY` with role `TENDER_TRANSFORM`, which owns `PROD_*`, and any pull request workflow could read the deploy key.
- The cleanup macro matched `CI_PR_3%`, which includes `CI_PR_35_*`.
- `dbt` wasn't a required check, so a pull request with a failing build could still merge.
- A deploy compared with the commit before its push. A deploy cancelled while queued, or one that failed, was never repeated.
- Nobody had checked whether a failed dbt command fails the task.
- The failure alerts only see runs that failed. After 3 failures in a row a task suspends itself, and from then on nothing is emailed. The dbt alert also looked back exactly 3 hours, so a run stopped by its 30-minute timeout at :50 could fall between two checks.
- Source freshness counted empty API pages and failed runs as new data.
- Nothing capped the warehouse's credits, and a statement could run for 2 days.
- The loader retried 10 times at 120 s, longer than the ingest task's 15-minute limit, so a rate-limited run was killed before it could log why.

## Decision
- **CI role:** role and service user `TENDER_CI` (`snowflake/setup/06_ci_role.sql`) build pull requests. They read `RAW` and create `CI_PR_*` schemas, nothing else. Its key is the `SNOWFLAKE_CI_PRIVATE_KEY` secret.
- **Deploy secrets** live in the GitHub environment `production`, which only `main` can deploy to, so pull request workflows can't read them.
- **Branch protection** on `main` requires `checks` and `dbt`, for admins too.
- **Exact cleanup:** `drop_ci_schemas` drops only schemas named the prefix plus at most one `_SUFFIX`.
- **Deploy catch-up:** the tag `deployed` marks the last successful deploy. Each deploy compares with it and moves it once every step has succeeded. A run for a commit older than the tag deploys nothing.
- **dbt failures:** checked on 2026-10-08. A missing macro, a database error and a failing test each make `EXECUTE DBT PROJECT` raise inside the task's script, so the run fails. The task is unchanged.
- **Alerts:**
  - `RUN_DBT_FAILED` now checks the runs that ended since its last successful check (`SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME()`).
  - A new alert, `PIPELINE_STALE`, emails when no load or no dbt run has succeeded for 4 hours. It checks at :50, by day only.
- **Freshness** counts only pages with releases, and successful runs.
- **Cost:**
  - resource monitor `TENDER_WH_MONITOR` on `TENDER_WH`: 30 credits a month, notify at 75%, suspend at 100%
  - statement timeout of 30 minutes on the warehouse
- **Loader:** 5 retries per request, so about 10 minutes of 429s.

## Consequences
- A pull request can't change or drop prod objects, whatever its `dbt/` change does.
- Merging needs green `checks` and `dbt`, also for the repository owner.
- The next merge or a manual run repairs a cancelled or failed deploy.
- A suspended task gets an email every 3 hours by day until it runs again. To pause the pipeline, suspend `PIPELINE_STALE` with the tasks.
- At 30 credits the warehouse stops for the rest of the month: dbt, CI and Power BI refreshes fail until the quota is raised. A warehouse monitor doesn't cover serverless loads or alerts.
- A long rate limit now makes a run give up sooner; the next run fetches the same window again.
