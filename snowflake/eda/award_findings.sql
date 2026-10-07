-- Award findings behind docs/eda-findings.md (Awards section). Read-only.
-- Run with: snow sql -c tender -f snowflake/eda/award_findings.sql

-- 2. Awards: rows, distinct, where value and date live, by notice type
SELECT
    COALESCE(n.notice_type, 'old regime') AS notice_type,
    COUNT(*) AS award_rows,
    COUNT(DISTINCT a.procurement_award_key) AS distinct_awards,
    ROUND(100 * COUNT_IF(a.awarded_at IS NOT NULL) / COUNT(*)) AS pct_with_award_date,
    ROUND(100 * COUNT_IF(a.award_value_amount IS NOT NULL OR a.award_value_amount_gross IS NOT NULL) / COUNT(*)) AS pct_with_award_value
FROM
    TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
INNER JOIN
    TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__NOTICES AS n
ON
    a.notice_id = n.notice_id
GROUP BY
    1
ORDER BY
    award_rows DESC;

-- 3. Per distinct award: value and date sources, contracts, frameworks, old regime
WITH award_rows AS (
    SELECT
        a.procurement_award_key,
        a.award_status,
        a.award_value_amount,
        a.award_value_amount_gross,
        a.award_value_currency,
        a.awarded_at,
        n.notice_type,
        n.published_at,
        n.buyer_id,
        n.cpv_code,
        n.title,
        n.notice:tender.techniques.hasFrameworkAgreement::BOOLEAN AS has_framework_agreement
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__NOTICES AS n
    ON
        a.notice_id = n.notice_id
),
contracts AS (
    SELECT
        procurement_award_key,
        COUNT(DISTINCT contract_id) AS contracts,
        MAX(contract_value_amount) AS contract_net,
        MAX(contract_value_amount_gross) AS contract_gross,
        MIN(signed_at) AS signed_at
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__CONTRACTS
    GROUP BY
        procurement_award_key
),
suppliers AS (
    SELECT
        a.procurement_award_key,
        COUNT(DISTINCT s.supplier_id) AS suppliers
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARD_SUPPLIERS AS s
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    ON
        s.award_key = a.award_key
    GROUP BY
        a.procurement_award_key
),
awards AS (
    SELECT
        procurement_award_key,
        MAX_BY(award_status, published_at) AS latest_status,
        BOOLOR_AGG(COALESCE(notice_type = 'UK15', FALSE)) AS is_uk15,
        BOOLAND_AGG(notice_type IS NULL) AS is_old_regime,
        MAX_BY(award_value_amount, IFF(award_value_amount IS NULL, NULL, published_at)) AS award_net,
        MAX_BY(award_value_amount_gross, IFF(award_value_amount_gross IS NULL, NULL, published_at)) AS award_gross,
        ANY_VALUE(award_value_currency) AS currency,
        MIN(awarded_at) AS awarded_at,
        MIN(published_at) AS first_published,
        COUNT(DISTINCT buyer_id) AS buyers,
        COUNT(DISTINCT cpv_code) AS cpvs,
        BOOLOR_AGG(COALESCE(has_framework_agreement, FALSE)) AS has_framework_agreement,
        BOOLOR_AGG(COALESCE(title ILIKE '%framework%', FALSE)) AS framework_in_title
    FROM
        award_rows
    GROUP BY
        procurement_award_key
),
enriched AS (
    SELECT
        a.*,
        COALESCE(c.contracts, 0) AS contracts,
        c.contract_net,
        c.contract_gross,
        c.signed_at,
        COALESCE(s.suppliers, 0) AS suppliers,
        a.has_framework_agreement OR COALESCE(s.suppliers, 0) >= 3 OR a.framework_in_title AS is_framework,
        COALESCE(a.award_net, c.contract_net, a.award_gross, c.contract_gross) AS chosen_value,
        CASE
            WHEN a.award_net IS NOT NULL THEN 'award net'
            WHEN c.contract_net IS NOT NULL THEN 'contract net'
            WHEN a.award_gross IS NOT NULL THEN 'award gross'
            WHEN c.contract_gross IS NOT NULL THEN 'contract gross'
            ELSE 'none'
        END AS value_source,
        CASE
            WHEN a.awarded_at IS NOT NULL THEN 'award date'
            WHEN c.signed_at IS NOT NULL THEN 'signed date'
            ELSE 'published date'
        END AS date_source
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
)
SELECT
    COUNT(*) AS distinct_awards,
    COUNT_IF(is_uk15) AS uk15,
    COUNT_IF(latest_status = 'cancelled') AS cancelled,
    COUNT_IF(latest_status = 'pending') AS pending,
    COUNT_IF(is_old_regime) AS old_regime,
    COUNT_IF(contracts > 1) AS awards_with_several_contracts,
    COUNT_IF(contracts = 0) AS awards_without_contract,
    COUNT_IF(suppliers = 0 AND NOT is_uk15) AS awards_without_supplier,
    COUNT_IF(buyers > 1) AS awards_with_several_buyers,
    COUNT_IF(cpvs > 1) AS awards_with_several_cpvs,
    COUNT_IF(award_net IS NOT NULL AND contract_net IS NOT NULL) AS net_both,
    COUNT_IF(award_net IS NOT NULL AND contract_net IS NOT NULL AND award_net = contract_net) AS net_both_equal,
    COUNT_IF(award_gross > 2 * award_net OR contract_gross > 2 * contract_net) AS gross_over_twice_net
FROM
    enriched;

-- 4. Value and date sources, frameworks and currencies (excluding UK15 and cancelled)
WITH award_rows AS (
    SELECT
        a.procurement_award_key,
        a.award_status,
        a.award_value_amount,
        a.award_value_amount_gross,
        a.award_value_currency,
        a.awarded_at,
        n.notice_type,
        n.published_at,
        n.buyer_id,
        n.cpv_code,
        n.title,
        n.notice:tender.techniques.hasFrameworkAgreement::BOOLEAN AS has_framework_agreement
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__NOTICES AS n
    ON
        a.notice_id = n.notice_id
),
contracts AS (
    SELECT
        procurement_award_key,
        COUNT(DISTINCT contract_id) AS contracts,
        MAX(contract_value_amount) AS contract_net,
        MAX(contract_value_amount_gross) AS contract_gross,
        MIN(signed_at) AS signed_at
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__CONTRACTS
    GROUP BY
        procurement_award_key
),
suppliers AS (
    SELECT
        a.procurement_award_key,
        COUNT(DISTINCT s.supplier_id) AS suppliers
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARD_SUPPLIERS AS s
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    ON
        s.award_key = a.award_key
    GROUP BY
        a.procurement_award_key
),
awards AS (
    SELECT
        procurement_award_key,
        MAX_BY(award_status, published_at) AS latest_status,
        BOOLOR_AGG(COALESCE(notice_type = 'UK15', FALSE)) AS is_uk15,
        BOOLAND_AGG(notice_type IS NULL) AS is_old_regime,
        MAX_BY(award_value_amount, IFF(award_value_amount IS NULL, NULL, published_at)) AS award_net,
        MAX_BY(award_value_amount_gross, IFF(award_value_amount_gross IS NULL, NULL, published_at)) AS award_gross,
        ANY_VALUE(award_value_currency) AS currency,
        MIN(awarded_at) AS awarded_at,
        MIN(published_at) AS first_published,
        COUNT(DISTINCT buyer_id) AS buyers,
        COUNT(DISTINCT cpv_code) AS cpvs,
        BOOLOR_AGG(COALESCE(has_framework_agreement, FALSE)) AS has_framework_agreement,
        BOOLOR_AGG(COALESCE(title ILIKE '%framework%', FALSE)) AS framework_in_title
    FROM
        award_rows
    GROUP BY
        procurement_award_key
),
enriched AS (
    SELECT
        a.*,
        COALESCE(c.contracts, 0) AS contracts,
        c.contract_net,
        c.contract_gross,
        c.signed_at,
        COALESCE(s.suppliers, 0) AS suppliers,
        a.has_framework_agreement OR COALESCE(s.suppliers, 0) >= 3 OR a.framework_in_title AS is_framework,
        COALESCE(a.award_net, c.contract_net, a.award_gross, c.contract_gross) AS chosen_value,
        CASE
            WHEN a.award_net IS NOT NULL THEN 'award net'
            WHEN c.contract_net IS NOT NULL THEN 'contract net'
            WHEN a.award_gross IS NOT NULL THEN 'award gross'
            WHEN c.contract_gross IS NOT NULL THEN 'contract gross'
            ELSE 'none'
        END AS value_source,
        CASE
            WHEN a.awarded_at IS NOT NULL THEN 'award date'
            WHEN c.signed_at IS NOT NULL THEN 'signed date'
            ELSE 'published date'
        END AS date_source
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
)
, scoped AS (
    SELECT
        *,
        COALESCE(currency, 'GBP') = 'GBP' AS is_gbp
    FROM
        enriched
    WHERE
        NOT is_uk15
        AND COALESCE(latest_status, '') != 'cancelled'
)
SELECT
    'value source' AS breakdown,
    value_source AS category,
    COUNT(*) AS awards,
    ROUND(SUM(IFF(is_gbp AND NOT is_framework, chosen_value, 0)) / 1e6) AS gbp_m_non_framework
FROM
    scoped
GROUP BY
    category
UNION ALL
SELECT
    'date source',
    date_source,
    COUNT(*),
    NULL
FROM
    scoped
GROUP BY
    date_source
UNION ALL
SELECT
    'framework',
    IFF(is_framework, 'framework set-up', 'other') || IFF(is_old_regime, ' (old regime)', ' (Act)'),
    COUNT(*),
    ROUND(SUM(IFF(is_gbp, chosen_value, 0)) / 1e6)
FROM
    scoped
GROUP BY
    2
UNION ALL
SELECT
    'currency',
    COALESCE(currency, 'none'),
    COUNT(*),
    NULL
FROM
    scoped
WHERE
    COALESCE(currency, 'GBP') != 'GBP'
GROUP BY
    currency
UNION ALL
SELECT
    'award to signed days (median)',
    'both dates present',
    COUNT(*),
    MEDIAN(DATEDIFF(DAY, awarded_at, signed_at))
FROM
    scoped
WHERE
    awarded_at IS NOT NULL
    AND signed_at IS NOT NULL
ORDER BY
    1,
    3 DESC;

-- 5. Non-framework GBP awards by size: where to draw the large-value line
WITH award_rows AS (
    SELECT
        a.procurement_award_key,
        a.award_status,
        a.award_value_amount,
        a.award_value_amount_gross,
        a.award_value_currency,
        a.awarded_at,
        n.notice_type,
        n.published_at,
        n.buyer_id,
        n.cpv_code,
        n.title,
        n.notice:tender.techniques.hasFrameworkAgreement::BOOLEAN AS has_framework_agreement
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__NOTICES AS n
    ON
        a.notice_id = n.notice_id
),
contracts AS (
    SELECT
        procurement_award_key,
        COUNT(DISTINCT contract_id) AS contracts,
        MAX(contract_value_amount) AS contract_net,
        MAX(contract_value_amount_gross) AS contract_gross,
        MIN(signed_at) AS signed_at
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__CONTRACTS
    GROUP BY
        procurement_award_key
),
suppliers AS (
    SELECT
        a.procurement_award_key,
        COUNT(DISTINCT s.supplier_id) AS suppliers
    FROM
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARD_SUPPLIERS AS s
    INNER JOIN
        TENDER_DB.DEV_STAGING.STG_FIND_A_TENDER__AWARDS AS a
    ON
        s.award_key = a.award_key
    GROUP BY
        a.procurement_award_key
),
awards AS (
    SELECT
        procurement_award_key,
        MAX_BY(award_status, published_at) AS latest_status,
        BOOLOR_AGG(COALESCE(notice_type = 'UK15', FALSE)) AS is_uk15,
        BOOLAND_AGG(notice_type IS NULL) AS is_old_regime,
        MAX_BY(award_value_amount, IFF(award_value_amount IS NULL, NULL, published_at)) AS award_net,
        MAX_BY(award_value_amount_gross, IFF(award_value_amount_gross IS NULL, NULL, published_at)) AS award_gross,
        ANY_VALUE(award_value_currency) AS currency,
        MIN(awarded_at) AS awarded_at,
        MIN(published_at) AS first_published,
        COUNT(DISTINCT buyer_id) AS buyers,
        COUNT(DISTINCT cpv_code) AS cpvs,
        BOOLOR_AGG(COALESCE(has_framework_agreement, FALSE)) AS has_framework_agreement,
        BOOLOR_AGG(COALESCE(title ILIKE '%framework%', FALSE)) AS framework_in_title
    FROM
        award_rows
    GROUP BY
        procurement_award_key
),
enriched AS (
    SELECT
        a.*,
        COALESCE(c.contracts, 0) AS contracts,
        c.contract_net,
        c.contract_gross,
        c.signed_at,
        COALESCE(s.suppliers, 0) AS suppliers,
        a.has_framework_agreement OR COALESCE(s.suppliers, 0) >= 3 OR a.framework_in_title AS is_framework,
        COALESCE(a.award_net, c.contract_net, a.award_gross, c.contract_gross) AS chosen_value,
        CASE
            WHEN a.award_net IS NOT NULL THEN 'award net'
            WHEN c.contract_net IS NOT NULL THEN 'contract net'
            WHEN a.award_gross IS NOT NULL THEN 'award gross'
            WHEN c.contract_gross IS NOT NULL THEN 'contract gross'
            ELSE 'none'
        END AS value_source,
        CASE
            WHEN a.awarded_at IS NOT NULL THEN 'award date'
            WHEN c.signed_at IS NOT NULL THEN 'signed date'
            ELSE 'published date'
        END AS date_source
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
)
, scoped AS (
    SELECT
        chosen_value AS value,
        is_old_regime
    FROM
        enriched
    WHERE
        NOT is_uk15
        AND COALESCE(latest_status, '') != 'cancelled'
        AND NOT is_framework
        AND COALESCE(currency, 'GBP') = 'GBP'
        AND chosen_value > 0
)
SELECT
    IFF(is_old_regime, 'old regime', 'Act') AS regime,
    COUNT(*) AS awards,
    ROUND(MEDIAN(value) / 1e3) AS median_k,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY value) / 1e6, 1) AS p99_m,
    COUNT_IF(value >= 1e8) AS over_100m,
    COUNT_IF(value >= 5e8) AS over_500m,
    COUNT_IF(value >= 1e9) AS over_1bn,
    ROUND(SUM(value) / 1e9) AS total_bn,
    ROUND(SUM(IFF(value < 1e8, value, 0)) / 1e9) AS total_below_100m_bn,
    ROUND(SUM(IFF(value < 1e9, value, 0)) / 1e9) AS total_below_1bn_bn
FROM
    scoped
GROUP BY
    regime;
