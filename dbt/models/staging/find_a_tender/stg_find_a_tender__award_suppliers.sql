-- One row per supplier on an award. Supplier details are in parties.
-- A few notices list the same supplier twice on an award: keep one copy.
-- Unusable supplier names ("384441.61", "N/A", ...) are replaced with the same
-- supplier ID's latest usable name (docs/adr/0025-replace-unusable-organisation-names.md).

WITH award_suppliers AS (
    SELECT
        n.notice_id || '/' || a.value:id::STRING || '/' || s.value:id::STRING AS award_supplier_key,
        n.notice_id || '/' || a.value:id::STRING AS award_key,
        n.notice_id,
        a.value:id::STRING AS award_id,
        s.value:id::STRING AS supplier_id,
        s.value:name::STRING AS supplier_name,
        n.published_at
    FROM
        {{ ref('stg_find_a_tender__notices') }} AS n,
        LATERAL FLATTEN(input => n.notice:awards) AS a,
        LATERAL FLATTEN(input => a.value:suppliers) AS s
    QUALIFY
        ROW_NUMBER() OVER (PARTITION BY award_supplier_key ORDER BY s.index) = 1
),

usable_supplier_names AS (
    -- each supplier ID's latest name that can identify it
    SELECT
        supplier_id,
        MAX_BY(supplier_name, published_at) AS supplier_name
    FROM
        award_suppliers
    WHERE
        NOT {{ is_unusable_org_name('supplier_name') }}
    GROUP BY
        supplier_id
)

SELECT
    s.award_supplier_key,
    s.award_key,
    s.notice_id,
    s.award_id,
    s.supplier_id,
    IFF(
        {{ is_unusable_org_name('s.supplier_name') }},
        COALESCE(u.supplier_name, 'Unnamed supplier (' || s.supplier_id || ')'),
        s.supplier_name
    ) AS supplier_name
FROM
    award_suppliers AS s
LEFT JOIN
    usable_supplier_names AS u
ON
    s.supplier_id = u.supplier_id
