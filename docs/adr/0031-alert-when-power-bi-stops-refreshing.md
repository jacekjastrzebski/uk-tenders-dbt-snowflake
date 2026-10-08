# 0031. Alert from Snowflake when Power BI stops refreshing

Status: Accepted (2026-10-08)

## Context
Power BI Service refreshes the report five times a day. Its failure emails go only to addresses inside the Power BI tenant; the tenant is a free one with no mailbox, and an outside address (Gmail) is refused. A failed refresh would leave the public report silently out of date.

## Decision
A Snowflake alert, `TENDER_DB.DBT.POWERBI_REFRESH_MISSED` (owned by `TENDER_TRANSFORM`, like the dbt failure alert), runs 90 minutes after each scheduled refresh. If `TENDER_POWERBI` ran no successful query on `TENDER_WH` in the last 100 minutes, it emails the same recipient as the other alerts. `TENDER_TRANSFORM` gets `MONITOR` on `TENDER_WH` so it can see those queries. The alert is deployed by `deploy.yml` like the others.

## Consequences
- A failed or skipped refresh reaches the alert email within about 1½ hours.
- It checks that Power BI read the marts, not that every visual works: a refresh that reads the data but fails later in Power BI wouldn't be caught.
- If the refresh times change, the alert's schedule has to change with them.
