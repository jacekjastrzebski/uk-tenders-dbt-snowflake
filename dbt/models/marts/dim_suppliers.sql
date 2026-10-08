-- Suppliers: one row per organisation, grouped by normalised name (lot numbers
-- removed) because the same supplier can appear under several IDs and names.
-- The name shown is the one from the supplier's most recent notice.
-- Buyers can withhold a supplier's name (Procurement Act section 94): those
-- rows are flagged so "who's winning" can leave them out.

WITH supplier_notices AS (
    SELECT
        {{ normalise_org_name('s.supplier_name') }} AS supplier_key,
        s.supplier_id,
        {{ strip_lot_numbers('s.supplier_name') }} AS supplier_name,
        n.published_at
    FROM
        {{ ref('stg_find_a_tender__award_suppliers') }} AS s
    INNER JOIN
        {{ ref('stg_find_a_tender__notices') }} AS n
    ON
        s.notice_id = n.notice_id
    WHERE
        s.supplier_name IS NOT NULL
)

SELECT
    supplier_key,
    MAX_BY(supplier_name, published_at) AS supplier_name,
    ARRAY_TO_STRING(ARRAY_AGG(DISTINCT supplier_id) WITHIN GROUP (ORDER BY supplier_id), ', ') AS supplier_ids,
    -- a substring match on purpose: buyers spell the placeholder many ways, e.g.
    -- "Withheld Section94 supplier", "Details Withheld for security reasons"
    supplier_key ILIKE '%WITHHELD%' AS is_withheld
FROM
    supplier_notices
GROUP BY
    supplier_key

UNION ALL

-- Awards published without a supplier
SELECT
    'UNKNOWN SUPPLIER',
    'Unknown supplier',
    NULL,
    FALSE
