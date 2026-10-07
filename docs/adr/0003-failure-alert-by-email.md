# 0003. Email on failure with a scheduled alert

Status: Accepted (2026-10-07)

## Context
A failed load must be noticed. Task error notifications (`ERROR_INTEGRATION`) only support cloud queues (SNS, Event Grid, Pub/Sub), not email. Event-table alerts fire instantly but need extra setup, and the docs were inconsistent on details.

## Decision
One serverless alert, `INGEST_FIND_A_TENDER_FAILED`, at :30 after each load slot: if any ingest task failed in the last 3 hours, send an email with `SYSTEM$SEND_EMAIL` through integration `TENDER_EMAIL`. The recipient comes from the `ALERT_EMAIL` GitHub secret at deploy time, so no address is in the repo. Tasks also suspend after 3 failures in a row.

## Consequences
- Up to 30 minutes' delay; each failure is emailed once (checks are 3 hours apart).
- Covers every failure type, including timeouts.
- Revisit with event-based alerts once dbt also runs in Snowflake (README TO-DO), so one alert covers all tasks.
