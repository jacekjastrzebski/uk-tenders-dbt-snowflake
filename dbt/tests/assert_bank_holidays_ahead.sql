{{ config(severity='warn') }}   -- a warning: refresh the seed with ingestion/fetch_uk_bank_holidays.py

-- The bank holidays seed ends less than 6 months ahead, so the working-day alert
-- NOTICES_NOT_ARRIVING would soon email on bank holidays it doesn't know about.

SELECT
    MAX(holiday_date) AS last_holiday
FROM
    {{ ref('uk_bank_holidays') }}
HAVING
    MAX(holiday_date) < DATEADD(MONTH, 6, CURRENT_DATE())
