-- One row per loader run: the window it asked the API for, what came back and
-- how it ended. A run that finds no new notices (common at weekends) still
-- succeeds, so it still confirms the data is up to date. Timestamps are UTC.

SELECT
    run_id,
    run_type,
    status,
    window_from,
    window_to,
    pages,
    releases,
    error_message,
    finished_at
FROM
    {{ source('raw', 'find_a_tender_ingest_runs') }}
