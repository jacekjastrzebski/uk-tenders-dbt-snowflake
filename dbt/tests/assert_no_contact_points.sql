-- Personal contact details must not reach staging: no stored notice may
-- still contain a contactPoint (docs/adr/0016-strip-contact-details-in-staging.md).

SELECT
    notice_id
FROM
    {{ ref('stg_find_a_tender__notices') }}
WHERE
    CONTAINS(TO_JSON(notice), '"contactPoint"')
