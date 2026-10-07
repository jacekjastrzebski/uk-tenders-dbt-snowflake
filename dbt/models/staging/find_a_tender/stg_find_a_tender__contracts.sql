-- One row per contract in a notice.

SELECT
    n.notice_id || '/' || c.value:id::STRING AS contract_key,
    n.notice_id,
    n.ocid,
    c.value:id::STRING AS contract_id,
    c.value:awardID::STRING AS award_id,
    c.value:status::STRING AS contract_status,
    c.value:value.amount::NUMBER(38, 2) AS contract_value_amount,
    c.value:value.currency::STRING AS contract_value_currency,
    c.value:dateSigned::TIMESTAMP_TZ AS signed_at,
    c.value:period.startDate::TIMESTAMP_TZ AS starts_at,
    c.value:period.endDate::TIMESTAMP_TZ AS ends_at
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:contracts) AS c
