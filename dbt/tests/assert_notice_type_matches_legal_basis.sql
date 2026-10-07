{{ config(severity='warn') }}   -- a warning: publishers occasionally omit the notice type (1 notice in 172,000)

-- Procurement Act notices (legal basis 2023/54) have a notice type UK1-UK17;
-- older-regime notices have none. A disagreement means one of the two
-- derivations in stg_find_a_tender__notices is wrong.

SELECT
    notice_id,
    legal_basis,
    notice_type
FROM
    {{ ref('stg_find_a_tender__notices') }}
WHERE
    is_procurement_act IS DISTINCT FROM (notice_type IS NOT NULL)
