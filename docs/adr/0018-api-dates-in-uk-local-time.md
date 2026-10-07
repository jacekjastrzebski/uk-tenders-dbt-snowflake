# 0018. Send API window dates as UK local time

Status: Accepted (2026-10-07). Resolves the time zone risk left open in [ADR 0011](0011-load-window-overlap.md).

## Context
`updatedFrom` and `updatedTo` take no offset, and the API docs don't say which time zone they mean. The loader sent UTC. A test on 2026-10-07 showed the API reads them as UK local time:

| Request (10:00 to 11:00) | Notices returned | Reading |
|---|---|---|
| 2 December 2025 (GMT) | 10:00Z to 10:59Z | same as UTC in winter |
| 1 July 2025 (BST) | 10:05 to 10:57+01:00, i.e. 09:xx UTC | UK local time |

So during BST every window was one hour earlier than logged. Consecutive windows still joined up, so nothing was lost there. But when the clocks go back, 01:00–02:00 UK time happens twice, and a window that starts in that hour can skip one of them.

## Decision
- Convert each window to `Europe/London` before sending it (`api_dates()` in `ingestion/load_find_a_tender.py`). The run log keeps UTC.
- A window that spans the clocks going back starts one hour earlier, so the repeated hour is covered whichever way the API reads it.
- The stored procedure adds the `tzdata` package so the time zone works inside Snowflake.

## Consequences
- During BST, the first run after deploy fetches an extra hour; dbt removes the duplicates.
- One window a year, when the clocks go back, fetches an extra hour.
- Not verified: the API's handling of the repeated hour itself. The wider window covers both readings.
