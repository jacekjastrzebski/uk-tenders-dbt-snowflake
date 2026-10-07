-- One row per notice (OCDS release). The raw table holds API pages, and
-- overlapping load windows load some notices twice: keep the latest load.
-- Notices are classified by documents[].noticeType (UK1-UK17), not by tag,
-- which is too coarse (see docs/eda-findings.md).

WITH pages AS (
    SELECT
        payload,
        loaded_at
    FROM
        {{ source('raw', 'find_a_tender_releases') }}
),

releases AS (
    SELECT
        r.value AS notice,
        p.loaded_at
    FROM
        pages AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
    QUALIFY
        ROW_NUMBER() OVER (PARTITION BY r.value:id ORDER BY p.loaded_at DESC) = 1
),

notice_types AS (
    -- noticeType sits on documents in planning, tender, awards or contracts
    SELECT
        r.notice:id::STRING AS notice_id,
        MAX(d.value:noticeType::STRING) AS notice_type
    FROM
        releases AS r,
        LATERAL FLATTEN(input => r.notice, recursive => TRUE) AS d
    WHERE
        IS_OBJECT(d.value)
    GROUP BY
        notice_id
)

SELECT
    r.notice:id::STRING AS notice_id,
    r.notice:ocid::STRING AS ocid,
    r.notice:date::TIMESTAMP_TZ AS published_at,
    r.notice:tag AS tags,
    t.notice_type,
    t.notice_type IS NOT NULL AS is_procurement_act,
    r.notice:buyer.id::STRING AS buyer_id,
    r.notice:buyer.name::STRING AS buyer_name,
    r.notice:tender.title::STRING AS title,
    r.notice:tender.description::STRING AS description,
    r.notice:tender.status::STRING AS tender_status,
    r.notice:tender.value.amount::NUMBER(38, 2) AS tender_value_amount,
    r.notice:tender.value.currency::STRING AS tender_value_currency,
    r.notice:tender.tenderPeriod.endDate::TIMESTAMP_TZ AS tender_closing_at,
    COALESCE(
        r.notice:tender.classification.id::STRING,
        r.notice:tender.items[0].additionalClassifications[0].id::STRING,
        r.notice:awards[0].items[0].additionalClassifications[0].id::STRING
    ) AS cpv_code,
    r.loaded_at,
    r.notice
FROM
    releases AS r
LEFT JOIN
    notice_types AS t
ON
    r.notice:id::STRING = t.notice_id
