-- One row per distinct award (procurement_award_key), with the rules from
-- docs/eda-findings.md (Awards) applied:
--   value: award net, else contract net, else award gross, else contract gross,
--          collected across all notices of the award (UK7 repeats the award
--          without its value and date)
--   date:  earliest award date, else contract signed date, else first
--          publication date; as a UK date
--   GBP:   HMRC rate for the month of that date (ADR 0020); months outside
--          the rates table use the nearest month available
--   flags: framework set-ups, large values, dynamic-market admissions, cancelled

WITH award_rows AS (
    SELECT
        a.procurement_award_key,
        a.ocid,
        a.award_status,
        a.award_value_amount,
        a.award_value_amount_gross,
        a.award_value_currency,
        a.awarded_at,
        n.notice_type,
        n.published_at,
        n.buyer_name,
        n.cpv_code,
        n.title,
        n.notice:tender.techniques.hasFrameworkAgreement::BOOLEAN AS has_framework_agreement,
        n.notice:tender.procurementMethodDetails::STRING ILIKE 'Award under framework%' AS is_call_off
    FROM
        {{ ref('stg_find_a_tender__awards') }} AS a
    INNER JOIN
        {{ ref('stg_find_a_tender__notices') }} AS n
    ON
        a.notice_id = n.notice_id
),

awards AS (
    SELECT
        procurement_award_key,
        ANY_VALUE(ocid) AS ocid,
        MAX_BY(award_status, published_at) AS award_status,
        MAX_BY(buyer_name, published_at) AS buyer_name,
        MAX_BY(cpv_code, published_at) AS cpv_code,
        MAX_BY(title, published_at) AS title,
        MAX_BY(award_value_amount, IFF(award_value_amount IS NULL, NULL, published_at)) AS award_net,
        MAX_BY(award_value_amount_gross, IFF(award_value_amount_gross IS NULL, NULL, published_at)) AS award_gross,
        MAX_BY(award_value_currency, IFF(award_value_currency IS NULL, NULL, published_at)) AS award_currency,
        MIN(awarded_at) AS awarded_at,
        MIN(published_at) AS first_published_at,
        BOOLAND_AGG(notice_type IS NULL) AS is_old_regime,
        BOOLOR_AGG(COALESCE(notice_type IN ('UK14', 'UK15'), FALSE)) AS is_dynamic_market,
        BOOLOR_AGG(COALESCE(has_framework_agreement, FALSE)) AS has_framework_agreement,
        BOOLOR_AGG(COALESCE(is_call_off, FALSE)) AS is_call_off
    FROM
        award_rows
    GROUP BY
        procurement_award_key
),

contracts AS (
    SELECT
        procurement_award_key,
        MAX(contract_value_amount) AS contract_net,
        MAX(contract_value_amount_gross) AS contract_gross,
        MAX(contract_value_currency) AS contract_currency,
        MIN(signed_at) AS signed_at
    FROM
        {{ ref('stg_find_a_tender__contracts') }}
    GROUP BY
        procurement_award_key
),

suppliers AS (
    SELECT
        a.procurement_award_key,
        COUNT(DISTINCT {{ normalise_org_name('s.supplier_name') }}) AS supplier_count
    FROM
        {{ ref('stg_find_a_tender__award_suppliers') }} AS s
    INNER JOIN
        {{ ref('stg_find_a_tender__awards') }} AS a
    ON
        s.award_key = a.award_key
    GROUP BY
        a.procurement_award_key
),

rules AS (
    SELECT
        a.*,
        c.signed_at,
        COALESCE(s.supplier_count, 0) AS supplier_count,
        CASE
            WHEN a.award_net IS NOT NULL THEN 'award net'
            WHEN c.contract_net IS NOT NULL THEN 'contract net'
            WHEN a.award_gross IS NOT NULL THEN 'award gross'
            WHEN c.contract_gross IS NOT NULL THEN 'contract gross'
        END AS value_source,
        COALESCE(a.award_net, c.contract_net, a.award_gross, c.contract_gross) AS value,
        IFF(value_source LIKE 'award%', a.award_currency, c.contract_currency) AS currency,
        CASE
            WHEN a.awarded_at IS NOT NULL THEN 'award date'
            WHEN c.signed_at IS NOT NULL THEN 'signed date'
            ELSE 'published date'
        END AS date_source,
        CONVERT_TIMEZONE('UTC', 'Europe/London', COALESCE(a.awarded_at, c.signed_at, a.first_published_at))::DATE AS award_date
    FROM
        awards AS a
    LEFT JOIN
        contracts AS c
    ON
        a.procurement_award_key = c.procurement_award_key
    LEFT JOIN
        suppliers AS s
    ON
        a.procurement_award_key = s.procurement_award_key
),

rate_months AS (
    SELECT
        MIN(month_start) AS first_month,
        MAX(month_start) AS last_month
    FROM
        {{ ref('hmrc_exchange_rates') }}
)

SELECT
    r.procurement_award_key,
    r.ocid,
    r.award_status,
    r.award_date,
    r.date_source,
    {{ normalise_org_name('r.buyer_name') }} AS buyer_key,
    LEFT(r.cpv_code, 2) AS cpv_division,
    r.title,
    r.value,
    COALESCE(r.currency, 'GBP') AS currency,
    r.value_source,
    IFF(r.value_source LIKE '%gross', 'gross', 'net') AS value_basis,
    IFF(COALESCE(r.currency, 'GBP') = 'GBP', r.value, r.value / x.units_per_gbp) AS value_gbp,
    r.supplier_count,
    r.is_old_regime,
    r.is_dynamic_market,
    r.is_call_off,
    (r.has_framework_agreement OR r.supplier_count >= 3 OR COALESCE(r.title ILIKE '%framework%', FALSE))
        AND NOT r.is_call_off AS is_framework,
    COALESCE(value_gbp >= {{ var('large_award_gbp') }}, FALSE) AS is_large_value
FROM
    rules AS r
CROSS JOIN
    rate_months AS m
LEFT JOIN
    {{ ref('hmrc_exchange_rates') }} AS x
ON
    x.currency_code = r.currency
    AND x.month_start = LEAST(GREATEST(DATE_TRUNC(MONTH, r.award_date), m.first_month), m.last_month)
