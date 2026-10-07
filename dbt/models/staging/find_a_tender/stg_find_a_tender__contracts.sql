-- One row per contract in a notice. Its award can be in an earlier notice of
-- the same procurement (e.g. UK10, UK11), so link to awards on
-- procurement_award_key (ocid/award_id), not on the notice. Timestamps are UTC.

SELECT
    n.notice_id || '/' || c.value:id::STRING AS contract_key,
    n.ocid || '/' || c.value:awardID::STRING AS procurement_award_key,
    n.notice_id,
    n.ocid,
    c.value:id::STRING AS contract_id,
    c.value:awardID::STRING AS award_id,
    c.value:status::STRING AS contract_status,
    c.value:value.amount::NUMBER(38, 2) AS contract_value_amount,
    c.value:value.amountGross::NUMBER(38, 2) AS contract_value_amount_gross,
    c.value:value.currency::STRING AS contract_value_currency,
    CONVERT_TIMEZONE('UTC', c.value:dateSigned::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS signed_at,
    CONVERT_TIMEZONE('UTC', c.value:period.startDate::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS starts_at,
    CONVERT_TIMEZONE('UTC', c.value:period.endDate::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS ends_at
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:contracts) AS c
