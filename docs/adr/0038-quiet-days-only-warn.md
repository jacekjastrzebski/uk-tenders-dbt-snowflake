# 0038. Quiet days only warn; a working-day alert catches missing notices

Status: Accepted (2026-10-11). Changes the thresholds of [0010](0010-source-freshness-thresholds.md) and the notice freshness of [0033](0033-pipeline-safeguards.md).

## Context
Since 0033, freshness on `find_a_tender_releases` counts only pages that hold notices, and errors after 26 hours. On Sunday 11 Oct 2026 every load had succeeded, but none had brought notices since Saturday 13:00, so the 16:20 dbt run failed before the build and the failure email went out although nothing was wrong. In 19 months of data, weekdays bring 350–440 notices a day and never fewer than 15 in any 6 daytime hours; weekends bring about 6 a day, and bank holidays 0–17 (none on Christmas Day, Boxing Day afternoon or New Year's Day). A fixed number of hours can't tell a quiet weekend from a stopped feed.

## Decision
- Freshness on `find_a_tender_releases` (new notices) only warns, after 13 hours; it never fails the run. The thresholds are set per table, as a source-level `error_after` is inherited.
- Freshness on `find_a_tender_ingest_runs` (successful loader runs) keeps warn 13 h, error 26 h: a loader that stops still fails the run and emails.
- A new alert, `DBT.NOTICES_NOT_ARRIVING`, checks at 13:50, 16:50 and 19:50 on weekdays and emails when the last two scheduled loads both succeeded with no notices. It skips bank holidays in England and Wales, from the seed `uk_bank_holidays` (GOV.UK, written by `ingestion/fetch_uk_bank_holidays.py`, refreshed once a year; the test `assert_bank_holidays_ahead` warns 6 months before it runs out). It only emails: no new notices is not bad data, so dbt keeps building.

## Consequences
- Weekends and bank holidays fail nothing and email nothing; the build runs and "Data as of" moves on.
- A working day with nothing published is emailed the same afternoon.
- One more file to refresh once a year (the bank holidays seed).
