-- One row per award in a notice. The same award repeats in later notices of
-- the same procurement (ocid); procurement_award_key identifies it across them.
-- Timestamps are UTC.

SELECT
    n.notice_id || '/' || a.value:id::STRING AS award_key,
    n.ocid || '/' || a.value:id::STRING AS procurement_award_key,
    n.notice_id,
    n.ocid,
    a.value:id::STRING AS award_id,
    a.value:status::STRING AS award_status,
    CONVERT_TIMEZONE('UTC', a.value:date::TIMESTAMP_TZ)::TIMESTAMP_NTZ AS awarded_at,
    a.value:value.amount::NUMBER(38, 2) AS award_value_amount,
    a.value:value.amountGross::NUMBER(38, 2) AS award_value_amount_gross,
    a.value:value.currency::STRING AS award_value_currency
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:awards) AS a
