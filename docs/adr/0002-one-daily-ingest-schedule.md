# 0002. One ingest schedule for every day

Status: Accepted (2026-10-07). Supersedes the separate weekday/weekend tasks.

## Context
Ingestion first had two tasks: every 3 hours 07:00–19:00 on weekdays, and 07:00 and 19:00 at weekends (a task has one schedule). This made dbt and the failure alert hard to align: a dbt task can't follow two separate tasks (tasks in one graph need the same owner and schema), and schedules aligned to both wasted runs at weekends.

## Decision
One task, `INGEST_FIND_A_TENDER`, at `0 7,10,13,16,19 * * *` Europe/London, every day.

## Consequences
- Load at :00, dbt at :20, alert at :30: one pattern for everything.
- Six extra small loads a week; negligible cost; fresher weekend data.
- The deploy script drops the old `_WEEKDAYS` / `_WEEKENDS` tasks.
