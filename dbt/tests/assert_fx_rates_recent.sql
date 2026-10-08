{{ config(severity='warn') }}   -- a warning: refresh the seed with ingestion/fetch_hmrc_exchange_rates.py

-- Non-GBP awards converted with a rate more than 2 months older than the award:
-- the HMRC rates seed has fallen behind (int_awards takes the latest rate it has).

SELECT
    procurement_award_key,
    currency,
    award_date,
    rate_month
FROM
    {{ ref('int_awards') }}
WHERE
    currency <> 'GBP'
    AND rate_month < DATEADD(MONTH, -2, DATE_TRUNC(MONTH, award_date))
