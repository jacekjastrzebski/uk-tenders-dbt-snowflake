-- One row per award in a notice.

SELECT
    n.notice_id || '/' || a.value:id::STRING AS award_key,
    n.notice_id,
    n.ocid,
    a.value:id::STRING AS award_id,
    a.value:status::STRING AS award_status,
    a.value:date::TIMESTAMP_TZ AS awarded_at,
    a.value:value.amount::NUMBER(38, 2) AS award_value_amount,
    a.value:value.currency::STRING AS award_value_currency
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:awards) AS a
