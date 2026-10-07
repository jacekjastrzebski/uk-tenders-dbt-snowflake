# 0005. Deploy on merge, only the objects whose files changed

Status: Accepted (2026-10-07)

## Context
Code must reach Snowflake reliably after review, without re-creating objects that did not change.

## Decision
`.github/workflows/deploy.yml` runs on pushes to `main` that touch the loader or scripts `02`–`04`. Each step runs only if its own file changed: upload the loader, recreate the procedure, the task or the alert. A manual run deploys everything. One-off setup (`00`, `01`) stays manual.

## Consequences
- Merging a PR is the deploy; no separate release step.
- Deploying during a load is safe: a replaced task lets its current run finish, and the next load re-fetches from the last successful run.
- The workflow can only be triggered from `main`, so it is first tested by a real merge.
