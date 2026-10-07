-- Check the historical backfill (ADR 0017). Read-only.
-- Run with: snow sql -c tender -f snowflake/checks/backfill_coverage.sql

-- Days loaded: one successful run per day (a day that failed and then succeeded counts once)
SELECT
    COUNT(DISTINCT window_to) AS days_loaded,
    SUM(releases) AS releases,
    MIN(window_to) AS first_day_end,
    MAX(window_to) AS last_day_end
FROM
    TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS
WHERE
    run_type = 'backfill'
    AND status = 'success';

-- Days still missing: a failed run and no successful one for the same window; expect no rows.
-- Re-run the backfill to load them.
SELECT
    window_to,
    MAX(finished_at) AS last_failed_at,
    MAX_BY(error_message, finished_at) AS last_error
FROM
    TENDER_DB.RAW.FIND_A_TENDER_INGEST_RUNS
WHERE
    run_type = 'backfill'
GROUP BY
    window_to
HAVING
    COUNT_IF(status = 'success') = 0
ORDER BY
    window_to;

-- Weekdays since 24 February 2025 with no notices published: each one is a likely gap.
-- Bank holidays (e.g. Christmas Day) show up here too and are expected.
WITH days AS (
    SELECT
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2025-02-24'::DATE) AS day
    FROM
        TABLE(GENERATOR(ROWCOUNT => 3660))  -- ten years; must be a constant, days after today are filtered out
),

notices_per_day AS (
    SELECT
        r.value:date::TIMESTAMP_TZ::DATE AS day,
        COUNT(DISTINCT r.value:id::STRING) AS notices
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
    GROUP BY
        day
)

SELECT
    d.day,
    DAYNAME(d.day) AS weekday
FROM
    days AS d
LEFT JOIN
    notices_per_day AS n
ON
    d.day = n.day
WHERE
    d.day < CURRENT_DATE
    AND DAYOFWEEKISO(d.day) <= 5
    AND n.day IS NULL
ORDER BY
    d.day;
