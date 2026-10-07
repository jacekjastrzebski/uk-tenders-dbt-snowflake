-- Every CPV division used by a notice must exist in the cpv_divisions seed;
-- otherwise it would show as blank in the dashboard.

SELECT DISTINCT
    LEFT(n.cpv_code, 2) AS cpv_division
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n
LEFT JOIN
    {{ ref('cpv_divisions') }} AS d
ON
    LEFT(n.cpv_code, 2) = d.cpv_division
WHERE
    n.cpv_code IS NOT NULL
    AND d.cpv_division IS NULL
