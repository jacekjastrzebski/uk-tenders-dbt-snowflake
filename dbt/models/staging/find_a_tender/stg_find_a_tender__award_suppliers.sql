-- One row per supplier on an award. Supplier details are in parties.
-- A few notices list the same supplier twice on an award: keep one copy.

SELECT
    n.notice_id || '/' || a.value:id::STRING || '/' || s.value:id::STRING AS award_supplier_key,
    n.notice_id || '/' || a.value:id::STRING AS award_key,
    n.notice_id,
    a.value:id::STRING AS award_id,
    s.value:id::STRING AS supplier_id,
    s.value:name::STRING AS supplier_name
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:awards) AS a,
    LATERAL FLATTEN(input => a.value:suppliers) AS s
QUALIFY
    ROW_NUMBER() OVER (PARTITION BY award_supplier_key ORDER BY s.index) = 1
