-- Buyers: one row per organisation, grouped by normalised name because the
-- same buyer appears under several IDs (old Find a Tender, PPON, ...).
-- The name shown is the one from the buyer's most recent notice.

WITH buyer_notices AS (
    SELECT
        {{ normalise_org_name('buyer_name') }} AS buyer_key,
        buyer_id,
        buyer_name,
        published_at
    FROM
        {{ ref('stg_find_a_tender__notices') }}
    WHERE
        buyer_name IS NOT NULL
)

SELECT
    buyer_key,
    MAX_BY(buyer_name, published_at) AS buyer_name,
    ARRAY_TO_STRING(ARRAY_AGG(DISTINCT buyer_id) WITHIN GROUP (ORDER BY buyer_id), ', ') AS buyer_ids
FROM
    buyer_notices
GROUP BY
    buyer_key
