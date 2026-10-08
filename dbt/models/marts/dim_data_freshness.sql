-- One row: when the marts' data was last loaded from the API, in UK time,
-- for the report's "Data loaded" card. Power BI can't read RAW, so it comes
-- from the latest load time in staging.

SELECT
    CONVERT_TIMEZONE('UTC', 'Europe/London', MAX(loaded_at)) AS last_loaded_at
FROM
    {{ ref('stg_find_a_tender__notices') }}
