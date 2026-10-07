# 0006. Keep loader constants in code

Status: Accepted (2026-10-07). Details: [plans/loader-config.md](../plans/loader-config.md).

## Context
The API URL, date format and table names are constants at the top of the loader. A config file was considered.

## Decision
Keep them as constants. Environment-specific values (database, warehouse) already come from the Snowflake connection.

## Consequences
- The procedure imports a single file; no extra upload or lookup inside the Snowflake sandbox.
- If environments ever need different tables, use procedure arguments with defaults, not a file (see the plan).
