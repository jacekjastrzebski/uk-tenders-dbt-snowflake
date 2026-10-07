-- Calendar: one row per day between the vars dim_dates_start and dim_dates_end
-- (dbt_project.yml). UK financial year runs April to March: shifting a date
-- back 3 months turns April into January, so the shifted date gives the
-- financial year and the month within it.

WITH days AS (
    SELECT
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '{{ var("dim_dates_start") }}'::DATE) AS calendar_date
    FROM
        TABLE(GENERATOR(ROWCOUNT => 20000))   -- more days than the range needs (about 55 years)
)

SELECT
    calendar_date,
    YEAR(calendar_date) AS calendar_year,
    MONTH(calendar_date) AS month_number,
    TO_CHAR(calendar_date, 'MMMM') AS month_name,
    DATE_TRUNC(MONTH, calendar_date) AS month_start,
    TO_CHAR(calendar_date, 'YYYY-MM') AS year_month,
    DATEADD(DAY, 1 - DAYOFWEEKISO(calendar_date), calendar_date) AS week_start,   -- Monday
    YEAR(DATEADD(MONTH, -3, calendar_date)) || '/' || RIGHT(YEAR(DATEADD(MONTH, -3, calendar_date)) + 1, 2) AS financial_year,
    MONTH(DATEADD(MONTH, -3, calendar_date)) AS financial_month_number   -- April = 1, March = 12
FROM
    days
WHERE
    calendar_date <= '{{ var("dim_dates_end") }}'
