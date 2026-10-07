-- Check that scheduled ingestion is working. Read-only.
-- Run with: snow sql -c tender -f snowflake/checks/ingest_health.sql

-- Last runs: one row per run
SELECT run_id, window_from, window_to, pages, releases, status, error_message, finished_at
FROM TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS
ORDER BY finished_at DESC
LIMIT 10;

-- Freshness: hours since the last successful scheduled run (under ~3.5 between 07:00 and 19:00, up to ~12 overnight)
SELECT DATEDIFF('minute', MAX(finished_at), SYSDATE()) / 60 AS hours_since_success
FROM TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS
WHERE status = 'success'
  AND COALESCE(run_type, 'incremental') = 'incremental';  -- backfill runs say nothing about the schedule

-- What landed: releases per run
SELECT run_id, COUNT(*) AS pages, SUM(ARRAY_SIZE(payload:releases)) AS releases
FROM TENDER_DB.RAW.FIND_A_TENDER_RELEASES
GROUP BY run_id
ORDER BY run_id DESC;
