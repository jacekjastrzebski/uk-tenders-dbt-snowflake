-- Splitting awards between suppliers must not create or lose value:
-- allocated values add up to the award values.

WITH by_award AS (
    SELECT
        procurement_award_key,
        ANY_VALUE(award_value_gbp) AS award_value_gbp,
        SUM(allocated_value_gbp) AS allocated_value_gbp
    FROM
        {{ ref('fct_award_suppliers') }}
    GROUP BY
        procurement_award_key
)

SELECT
    procurement_award_key,
    award_value_gbp,
    allocated_value_gbp
FROM
    by_award
WHERE
    ABS(COALESCE(award_value_gbp, 0) - COALESCE(allocated_value_gbp, 0)) > 0.01
