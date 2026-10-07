-- Splitting awards between suppliers must not create or lose value: each
-- award's allocated values add up to its value in int_awards.

WITH allocated AS (
    SELECT
        procurement_award_key,
        SUM(allocated_value_gbp) AS allocated_value_gbp
    FROM
        {{ ref('fct_award_suppliers') }}
    GROUP BY
        procurement_award_key
)

SELECT
    a.procurement_award_key,
    a.value_gbp,
    f.allocated_value_gbp
FROM
    allocated AS f
INNER JOIN
    {{ ref('int_awards') }} AS a
ON
    f.procurement_award_key = a.procurement_award_key
WHERE
    ABS(COALESCE(a.value_gbp, 0) - COALESCE(f.allocated_value_gbp, 0)) > 0.01
