-- dim_dates must cover the configured range (vars dim_dates_start and
-- dim_dates_end) with exactly one row per day.

SELECT
    MIN(calendar_date) AS first_day,
    MAX(calendar_date) AS last_day,
    COUNT(*) AS days
FROM
    {{ ref('dim_dates') }}
HAVING
    MIN(calendar_date) != '{{ var("dim_dates_start") }}'
    OR MAX(calendar_date) != '{{ var("dim_dates_end") }}'
    OR COUNT(*) != DATEDIFF(DAY, MIN(calendar_date), MAX(calendar_date)) + 1
