# 0027. A browse-only guest role with no warehouse

Status: Accepted (2026-10-08)

## Context
Reviewers want to look around the Snowflake account: which schemas and tables exist, what the columns are, and how the scheduled tasks run. The code and the Power BI report are public, but the account is not. Any role that can query uses warehouse credits, and `RAW` still holds buyer contact details ([ADR 0016](0016-strip-contact-details-in-staging.md)).

## Decision
- Role `TENDER_VIEWER` (`snowflake/setup/05_viewer_role.sql`) has `USAGE` on the database and every schema, `REFERENCES` on every table and view, and `MONITOR` on every task, current and future.
- It has no warehouse, so it can't run queries, and `REFERENCES` shows structure, not rows.
- Each guest is a person user (`TYPE = PERSON`) with a temporary password they must change at first sign-in, holding this role only. The user name and password are passed in with `snow sql -D`, so no guest's name or password is committed to this public repo.

## Consequences
- A guest costs nothing and can't see any data, including contact details in `RAW`.
- To show data, a guest would need `SELECT` on the marts and a warehouse of their own, capped by a resource monitor; not done.
- Snowsight may need a warehouse for some views, such as task run history; a guest without one doesn't see them.
- Turn a guest off with `ALTER USER <name> SET DISABLED = TRUE`.
