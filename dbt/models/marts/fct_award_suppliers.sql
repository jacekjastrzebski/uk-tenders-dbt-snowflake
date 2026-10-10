-- One row per supplier on an award, for "Who's buying?" and "Who's winning?".
-- Awards come from int_awards (one row per award, rules applied); each award's
-- GBP value is split equally between its distinct suppliers, so supplier
-- totals add up to the award totals. Awards without a supplier get one
-- "Unknown supplier" row, so they still count for their buyer.
-- Dynamic-market admissions, cancelled awards and "unsuccessful" awards (a lot
-- nobody won: no supplier, no value) are left out. Framework set-ups, large
-- values and awards under the old rules stay in, flagged, outside the headline.
-- competition and supplier_scale are explained in ADR 0035.

WITH awards AS (
    SELECT
        *
    FROM
        {{ ref('int_awards') }}
    WHERE
        NOT is_dynamic_market
        AND COALESCE(award_status, '') NOT IN ('cancelled', 'unsuccessful')
),

award_suppliers AS (
    SELECT DISTINCT
        a.procurement_award_key,
        {{ normalise_org_name('s.supplier_name') }} AS supplier_key
    FROM
        {{ ref('stg_find_a_tender__award_suppliers') }} AS s
    INNER JOIN
        {{ ref('stg_find_a_tender__awards') }} AS a
    ON
        s.award_key = a.award_key
    WHERE
        s.supplier_name IS NOT NULL
),

supplier_scales AS (
    -- the size each supplier declares on the award's notices: the latest notice that gives one
    SELECT
        a.procurement_award_key,
        {{ normalise_org_name('s.supplier_name') }} AS supplier_key,
        p.scale
    FROM
        {{ ref('stg_find_a_tender__award_suppliers') }} AS s
    INNER JOIN
        {{ ref('stg_find_a_tender__awards') }} AS a
    ON
        s.award_key = a.award_key
    INNER JOIN
        {{ ref('stg_find_a_tender__parties') }} AS p
    ON
        s.notice_id = p.notice_id
        AND s.supplier_id = p.party_id
    INNER JOIN
        {{ ref('stg_find_a_tender__notices') }} AS n
    ON
        s.notice_id = n.notice_id
    WHERE
        s.supplier_name IS NOT NULL
        AND p.scale IS NOT NULL
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY a.procurement_award_key, supplier_key
            ORDER BY n.published_at DESC, n.notice_id DESC
        ) = 1
),

award_supplier_rows AS (
    SELECT
        a.*,
        COALESCE(s.supplier_key, 'UNKNOWN SUPPLIER') AS supplier_key,
        GREATEST(a.supplier_count, 1) AS suppliers_on_award,   -- counted in int_awards; 1 for "Unknown supplier"
        sc.scale
    FROM
        awards AS a
    LEFT JOIN
        award_suppliers AS s
    ON
        a.procurement_award_key = s.procurement_award_key
    LEFT JOIN
        supplier_scales AS sc
    ON
        s.procurement_award_key = sc.procurement_award_key
        AND s.supplier_key = sc.supplier_key
)

SELECT
    procurement_award_key || '/' || supplier_key AS award_supplier_key,
    procurement_award_key,
    ocid,
    award_date,
    buyer_key,
    supplier_key,
    cpv_division,
    award_status,
    value_gbp / suppliers_on_award AS allocated_value_gbp,
    suppliers_on_award,
    value_source,
    date_source,
    is_framework,
    is_large_value,
    is_old_regime,
    NOT is_framework AND NOT is_large_value AND NOT is_old_regime AND value_gbp IS NOT NULL AS is_in_headline,
    -- direct: a direct award or a below-threshold contract given without competition
    CASE
        WHEN procurement_method = 'direct' THEN 'Direct award'
        WHEN procurement_method IN ('open', 'selective', 'limited') THEN 'Competed'
        ELSE 'Not stated'
    END AS competition,
    CASE scale
        WHEN 'sme' THEN 'SME'
        WHEN 'large' THEN 'Large'
        ELSE 'Not stated'
    END AS supplier_scale
FROM
    award_supplier_rows
