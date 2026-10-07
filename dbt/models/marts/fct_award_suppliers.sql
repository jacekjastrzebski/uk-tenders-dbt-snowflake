-- One row per supplier on an award, for "Who's buying?" and "Who's winning?".
-- Awards come from int_awards (one row per award, rules applied); each award's
-- GBP value is split equally between its distinct suppliers, so supplier
-- totals add up to the award totals. Awards without a supplier get one
-- "Unknown supplier" row, so they still count for their buyer.
-- Dynamic-market admissions and cancelled awards are left out. Framework
-- set-ups and large values stay in, flagged, for separate views.

WITH awards AS (
    SELECT
        *
    FROM
        {{ ref('int_awards') }}
    WHERE
        NOT is_dynamic_market
        AND award_status IS DISTINCT FROM 'cancelled'
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
        COUNT(*) OVER (PARTITION BY a.procurement_award_key) AS suppliers_on_award
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
    value_gbp AS award_value_gbp,
    value_gbp / suppliers_on_award AS allocated_value_gbp,
    suppliers_on_award,
    value_basis,
    value_source,
    date_source,
    is_framework,
    is_large_value,
    is_old_regime,
    NOT is_framework AND NOT is_large_value AND value_gbp IS NOT NULL AS is_in_headline
FROM
    award_supplier_rows
