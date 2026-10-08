-- One row per Procurement Act tender (a procurement with a UK4 tender notice),
-- for "What's open to bid?" and "How long to award?".
-- Dates are UK dates of the notices' publication; "open" is worked out in
-- Power BI (closing date from today, no award, not cancelled), so it never
-- goes stale between refreshes.

WITH notices AS (
    SELECT
        ocid,
        notice_type,
        published_at,
        buyer_name,
        cpv_code,
        title,
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

latest_tender AS (
    -- the latest tender notice: updates can move the closing date either way
    SELECT
        ocid,
        buyer_name,
        cpv_code,
        title,
        closing_date
    FROM
        notices
    WHERE
        notice_type = 'UK4'
    QUALIFY
        ROW_NUMBER() OVER (PARTITION BY ocid ORDER BY published_at DESC) = 1
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
        t.buyer_name,
        t.cpv_code,
        t.title,
        IFF(t.closing_date BETWEEN '{{ var("dim_dates_start") }}' AND '{{ var("dim_dates_end") }}', t.closing_date, NULL) AS closing_date,
        CONVERT_TIMEZONE('UTC', 'Europe/London', m.tender_published_at)::DATE AS tender_published_date,
        -- award notice, or the contract notice for below-threshold contracts that skip it
        CONVERT_TIMEZONE('UTC', 'Europe/London', COALESCE(m.award_notice_published_at, m.contract_published_at))::DATE AS award_published_date,
        CONVERT_TIMEZONE('UTC', 'Europe/London', m.contract_published_at)::DATE AS contract_published_date,
        m.has_termination_notice
    FROM
        latest_tender AS t
    INNER JOIN
        milestones AS m
    ON
        t.ocid = m.ocid
)

SELECT
    ocid,
    {{ normalise_org_name('buyer_name') }} AS buyer_key,
    COALESCE(LEFT(cpv_code, 2), 'UNKNOWN') AS cpv_division,   -- no CPV code: "Unknown sector" in dim_cpv_divisions
    title,
    tender_published_date,
    closing_date,
    award_published_date,
    contract_published_date,
    -- notices published out of order would give negative durations: unknown instead
    IFF(DATEDIFF(DAY, tender_published_date, award_published_date) >= 0, DATEDIFF(DAY, tender_published_date, award_published_date), NULL) AS days_tender_to_award,
    IFF(DATEDIFF(DAY, award_published_date, contract_published_date) >= 0, DATEDIFF(DAY, award_published_date, contract_published_date), NULL) AS days_award_to_contract,
    -- a termination notice after an award is about a lot, not the whole procurement
    has_termination_notice AND award_published_date IS NULL AS is_cancelled
FROM
    dates
