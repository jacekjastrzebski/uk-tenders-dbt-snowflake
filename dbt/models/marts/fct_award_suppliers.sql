-- One row per supplier on an award, for "Who's buying?" and "Who's winning?".
-- Awards come from int_awards (one row per award, rules applied); each award's
-- GBP value is split equally between its distinct suppliers, so supplier
-- totals add up to the award totals. Awards without a supplier get one
-- "Unknown supplier" row, so they still count for their buyer.
-- Dynamic-market admissions, cancelled awards and "unsuccessful" awards (a lot
-- nobody won: no supplier, no value) are left out. Framework set-ups, large
-- values and awards under the old rules stay in, flagged, outside the headline.

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

award_supplier_rows AS (
    SELECT
        a.*,
        COALESCE(s.supplier_key, 'UNKNOWN SUPPLIER') AS supplier_key,
        GREATEST(a.supplier_count, 1) AS suppliers_on_award   -- counted in int_awards; 1 for "Unknown supplier"
    FROM
        awards AS a
    LEFT JOIN
        award_suppliers AS s
    ON
        a.procurement_award_key = s.procurement_award_key
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
    NOT is_framework AND NOT is_large_value AND NOT is_old_regime AND value_gbp IS NOT NULL AS is_in_headline
FROM
    award_supplier_rows
