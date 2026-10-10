-- One row: when the data was last confirmed up to date, in UK time, for the
-- report's "Data as of". That's the end of the window the latest successful
-- scheduled run asked the API for. The latest notice's load time would lag
-- whenever a run finds nothing new, as at weekends; backfills of past windows
-- don't count.

SELECT
    CONVERT_TIMEZONE('UTC', 'Europe/London', MAX(window_to)) AS last_loaded_at
FROM
    {{ ref('stg_find_a_tender__ingest_runs') }}
WHERE
    run_type = 'incremental'
    AND status = 'success'
