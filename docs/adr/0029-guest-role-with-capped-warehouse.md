# 0029. A guest role with its own capped warehouse

Status: Accepted (2026-10-08)

## Context
Reviewers want to look around the Snowflake account: which schemas and tables exist, how the scheduled tasks run, and what the data looks like at each layer. The code and the Power BI report are public, but the account is not, and queries use warehouse credits.

## Decision
- Role `TENDER_VIEWER` (`snowflake/setup/05_viewer_role.sql`) has `USAGE` on the database and every schema, `REFERENCES` on every table and view (structure, not rows) and `MONITOR` on every task, current and future.
- It can `SELECT` from `RAW`, `PROD_STAGING`, `PROD_INTERMEDIATE` and `PROD_MARTS`; not from the `DEV_*` schemas.
- It queries on its own X-Small warehouse, `TENDER_VIEWER_WH`. A resource monitor caps that warehouse at 1 credit a month: it notifies at 80% and suspends at 100%. Queries stop after 5 minutes.
- Every role inherits `PUBLIC`, and new accounts give `PUBLIC` a learning warehouse, the notebook warehouse and two compute pools. The script revokes these, so the capped warehouse is the guest's only compute.
- Each guest is a person user (`TYPE = PERSON`) with a temporary password they must change at first sign-in, holding this role only. The user name and password are passed in with `snow sql -D`, so no guest's name or password is committed to this public repo.

## Consequences
- A guest costs at most 1 credit a month.
- A guest can see buyer contact details in `RAW`, which staging strips ([ADR 0016](0016-strip-contact-details-in-staging.md)). They are published on Find a Tender, but give this role only to people you trust with them.
- The guest warehouse is separate from `TENDER_WH`, so guest queries never slow down or suspend the pipeline.
- Removing the grants from `PUBLIC` affects every user in the account; in a shared account, check that nobody relies on them first.
- Turn a guest off with `ALTER USER <name> SET DISABLED = TRUE`.
