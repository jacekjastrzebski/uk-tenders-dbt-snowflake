-- One row per Procurement Act tender (a procurement with a UK4 tender notice),
-- for "What's open to bid?" and "How long to award?".
-- Dates are UK dates of the notices' publication; "open" is worked out in
-- Power BI (closing date from today, no award, not cancelled), so it never
-- goes stale between refreshes. Value, framework and SME suitability come from
-- the latest tender notice (ADR 0035).

WITH notices AS (
    SELECT
        ocid,
        notice_id,
        notice_type,
        published_at,
        buyer_name,
        COALESCE(cpv_code, procurement_cpv_code) AS cpv_code,
        title,
        notice:tender.value.amountGross::NUMBER(38, 2) AS tender_value_gross,
        notice:tender.value.currency::STRING AS tender_value_currency,
        COALESCE(notice:tender.techniques.hasFrameworkAgreement::BOOLEAN, FALSE) AS is_framework,
        -- bid deadline, or the expression-of-interest deadline in two-stage procedures
        COALESCE(
            CONVERT_TIMEZONE('UTC', 'Europe/London', tender_closing_at)::DATE,
            CONVERT_TIMEZONE('Europe/London', notice:tender.expressionOfInterestDeadline::TIMESTAMP_TZ)::DATE
        ) AS closing_date
    FROM
        {{ ref('stg_find_a_tender__notices') }}
    WHERE
        is_procurement_act
),

sme_suitable_notices AS (
    -- tender notices with at least one lot the buyer marks as suitable for SMEs
    SELECT DISTINCT
        n.notice_id
    FROM
        {{ ref('stg_find_a_tender__notices') }} AS n,
        LATERAL FLATTEN(input => n.notice:tender.lots) AS l
    WHERE
        n.notice_type = 'UK4'
        AND l.value:suitability.sme::BOOLEAN
),

latest_tender AS (
    -- the latest tender notice: updates can move the closing date either way
    SELECT
        ocid,
        notice_id,
        buyer_name,
        cpv_code,
        title,
        closing_date,
        tender_value_gross,
        tender_value_currency,
        is_framework
    FROM
        notices
    WHERE
        notice_type = 'UK4'
    QUALIFY
        ROW_NUMBER() OVER (PARTITION BY ocid ORDER BY published_at DESC, notice_id DESC) = 1
),

milestones AS (
    SELECT
        ocid,
        MIN(IFF(notice_type = 'UK4', published_at, NULL)) AS tender_published_at,
        MIN(IFF(notice_type = 'UK6', published_at, NULL)) AS award_notice_published_at,
        MIN(IFF(notice_type = 'UK7', published_at, NULL)) AS contract_published_at,
        COUNT_IF(notice_type = 'UK12') > 0 AS has_termination_notice
    FROM
        notices
    GROUP BY
        ocid
),

dates AS (
    SELECT
        t.ocid,
        t.notice_id AS tender_notice_id,
        t.buyer_name,
        t.cpv_code,
        t.title,
        t.tender_value_gross,
        t.tender_value_currency,
        t.is_framework,
        s.notice_id IS NOT NULL AS is_suitable_for_sme,
        IFF(t.closing_date BETWEEN '{{ var("dim_dates_start") }}' AND '{{ var("dim_dates_end") }}', t.closing_date, NULL) AS closing_date,
        CONVERT_TIMEZONE('UTC', 'Europe/London', m.tender_published_at)::DATE AS tender_published_date,
        -- award notice, or the contract notice for below-threshold contracts that skip it
        CONVERT_TIMEZONE('UTC', 'Europe/London', COALESCE(m.award_notice_published_at, m.contract_published_at))::DATE AS award_published_date,
        CONVERT_TIMEZONE('UTC', 'Europe/London', m.award_notice_published_at)::DATE AS award_notice_date,
        CONVERT_TIMEZONE('UTC', 'Europe/London', m.contract_published_at)::DATE AS contract_published_date,
        m.has_termination_notice
    FROM
        latest_tender AS t
    INNER JOIN
        milestones AS m
    ON
        t.ocid = m.ocid
    LEFT JOIN
        sme_suitable_notices AS s
    ON
        t.notice_id = s.notice_id
)

SELECT
    ocid,
    {{ normalise_org_name('buyer_name') }} AS buyer_key,
    COALESCE(LEFT(cpv_code, 2), 'UNKNOWN') AS cpv_division,   -- no CPV code: "Unknown sector" in dim_cpv_divisions
    title,
    tender_notice_id,
    'https://www.find-tender.service.gov.uk/Notice/' || tender_notice_id AS tender_notice_url,
    -- estimated value incl. VAT, as most tenders publish it; in GBP only (a few dozen are not)
    -- and never to be added up: framework values are spending caps (ADR 0035)
    IFF(tender_value_currency = 'GBP' AND tender_value_gross > 0, tender_value_gross, NULL) AS tender_value_gbp,
    is_framework,
    is_suitable_for_sme,
    tender_published_date,
    closing_date,
    award_published_date,
    contract_published_date,
    -- notices published out of order would give negative durations: unknown instead
    IFF(DATEDIFF(DAY, tender_published_date, award_published_date) >= 0, DATEDIFF(DAY, tender_published_date, award_published_date), NULL) AS days_tender_to_award,
    -- only with a real award notice: without one, award_published_date is the contract
    -- notice's own date, which would count as 0 days
    IFF(DATEDIFF(DAY, award_notice_date, contract_published_date) >= 0, DATEDIFF(DAY, award_notice_date, contract_published_date), NULL) AS days_award_to_contract,
    -- a termination notice after an award is about a lot, not the whole procurement
    has_termination_notice AND award_published_date IS NULL AS is_cancelled
FROM
    dates
