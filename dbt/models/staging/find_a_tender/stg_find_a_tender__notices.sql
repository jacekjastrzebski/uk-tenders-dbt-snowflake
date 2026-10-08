-- One row per notice (OCDS release). The raw table holds API pages, and
-- overlapping load windows load some notices twice: keep the latest load.
-- Notices are classified by documents[].noticeType (UK1-UK17), not by tag,
-- which is too coarse (see docs/eda-findings.md).
-- Contact details (parties[].contactPoint) are removed from the stored JSON
-- (docs/adr/0016-strip-contact-details-in-staging.md). Timestamps are UTC.
-- Unusable buyer names ("[]", "Test", ...) are replaced with the same buyer
-- ID's latest usable name (docs/adr/0025-replace-unusable-organisation-names.md).
-- procurement_cpv_code is the latest CPV code on any notice of the same procurement,
-- for notices that have none (award notices often leave it out).

WITH pages AS (
    SELECT
        run_id,
        page_number,
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
        ROW_NUMBER() OVER (
            PARTITION BY r.value:id::STRING
            ORDER BY p.loaded_at DESC, p.run_id DESC, p.page_number DESC
        ) = 1
),

notice_types AS (
    -- noticeType sits on the notice's own document (document id = notice id),
    -- inside planning, tender, awards or contracts
    SELECT
        r.notice:id::STRING AS notice_id,
        ANY_VALUE(d.value::STRING) AS notice_type
    FROM
        releases AS r,
        LATERAL FLATTEN(input => r.notice, recursive => TRUE) AS d
    WHERE
        d.key = 'noticeType'
        AND d.this:id::STRING = r.notice:id::STRING
    GROUP BY
        notice_id
),

parties AS (
    -- parties without contactPoint, and the buyer party for notices that
    -- have no buyer object (e.g. UK11, UK12)
    SELECT
        r.notice:id::STRING AS notice_id,
        ARRAY_AGG(OBJECT_DELETE(p.value, 'contactPoint')) WITHIN GROUP (ORDER BY p.index) AS parties_without_contacts,
        MAX(IFF(ARRAY_CONTAINS('buyer'::VARIANT, p.value:roles), p.value:id::STRING, NULL)) AS buyer_party_id,
        MAX(IFF(ARRAY_CONTAINS('buyer'::VARIANT, p.value:roles), p.value:name::STRING, NULL)) AS buyer_party_name
    FROM
        releases AS r,
        LATERAL FLATTEN(input => r.notice:parties) AS p
    GROUP BY
        notice_id
),

notices AS (
    SELECT
        r.notice:id::STRING AS notice_id,
        r.notice:ocid::STRING AS ocid,
        CONVERT_TIMEZONE('UTC', r.notice:date::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS published_at,
        r.notice:tag AS tags,
        t.notice_type,
        r.notice:tender.legalBasis.id::STRING AS legal_basis,
        COALESCE(r.notice:tender.legalBasis.id::STRING = '2023/54', FALSE) AS is_procurement_act,   -- no legal basis = not the Act
        COALESCE(r.notice:buyer.id::STRING, pt.buyer_party_id) AS buyer_id,
        COALESCE(r.notice:buyer.name::STRING, pt.buyer_party_name) AS buyer_name,
        r.notice:tender.title::STRING AS title,
        r.notice:tender.description::STRING AS description,
        r.notice:tender.status::STRING AS tender_status,
        r.notice:tender.value.amount::NUMBER(38, 2) AS tender_value_amount,
        r.notice:tender.value.amountGross::NUMBER(38, 2) AS tender_value_amount_gross,
        r.notice:tender.value.currency::STRING AS tender_value_currency,
        CONVERT_TIMEZONE('UTC', r.notice:tender.tenderPeriod.endDate::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS tender_closing_at,
        COALESCE(
            r.notice:tender.classification.id::STRING,
            r.notice:tender.items[0].additionalClassifications[0].id::STRING,
            r.notice:awards[0].items[0].additionalClassifications[0].id::STRING
        ) AS cpv_code,
        r.loaded_at,
        IFF(
            pt.notice_id IS NULL,
            r.notice,
            OBJECT_INSERT(r.notice, 'parties', pt.parties_without_contacts, TRUE)
        ) AS notice
    FROM
        releases AS r
    LEFT JOIN
        notice_types AS t
    ON
        r.notice:id::STRING = t.notice_id
    LEFT JOIN
        parties AS pt
    ON
        r.notice:id::STRING = pt.notice_id
),

usable_buyer_names AS (
    -- each buyer ID's latest name that can identify it
    SELECT
        buyer_id,
        MAX_BY(buyer_name, published_at) AS buyer_name
    FROM
        notices
    WHERE
        NOT {{ is_unusable_org_name('buyer_name') }}
    GROUP BY
        buyer_id
)

SELECT
    n.* REPLACE (
        IFF(
            {{ is_unusable_org_name('n.buyer_name') }},
            COALESCE(u.buyer_name, 'Unnamed buyer (' || n.buyer_id || ')'),
            n.buyer_name
        ) AS buyer_name
    ),
    LAST_VALUE(n.cpv_code) IGNORE NULLS OVER (
        PARTITION BY n.ocid
        ORDER BY n.published_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS procurement_cpv_code
FROM
    notices AS n
LEFT JOIN
    usable_buyer_names AS u
ON
    n.buyer_id = u.buyer_id
