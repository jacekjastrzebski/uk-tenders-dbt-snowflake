-- Every notice loaded into raw must reach staging; that it is there only once
-- is the unique test on stg_find_a_tender__notices.notice_id.

WITH raw_notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id
    FROM
        {{ source('raw', 'find_a_tender_releases') }} AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)

SELECT
    raw_notices.notice_id
FROM
    raw_notices
LEFT JOIN
    {{ ref('stg_find_a_tender__notices') }} AS n
ON
    raw_notices.notice_id = n.notice_id
WHERE
    n.notice_id IS NULL
