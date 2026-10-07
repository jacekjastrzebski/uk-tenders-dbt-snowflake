# 0010. Source freshness: warn at 13 h, error at 26 h

Status: Accepted (2026-10-07)

## Context
Freshness catches loads that stop arriving. The longest normal gap is overnight (19:00 to 07:00, 12 hours). An error fails the dbt task and triggers the failure email; a warning is only logged. A 13-hour error was considered, to get an email sooner.

## Decision
Warn after 13 hours (logged only), error after 26 hours (task fails, email).

## Consequences
- No false alarms on quiet periods.
- If loads stop entirely, the email arrives after about a day; the ingest failure alert (0003) usually reports failed loads within 30 minutes.
- `loaded_at` records when a load ran, not when new notices arrived: each load saves at least the first API page.
