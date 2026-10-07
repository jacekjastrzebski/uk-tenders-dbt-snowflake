-- dim_dates must have exactly one row per day between its first and last date.

SELECT
    COUNT(*) AS days,
    DATEDIFF(DAY, MIN(calendar_date), MAX(calendar_date)) + 1 AS expected_days
FROM
    {{ ref('dim_dates') }}
HAVING
    COUNT(*) != DATEDIFF(DAY, MIN(calendar_date), MAX(calendar_date)) + 1
