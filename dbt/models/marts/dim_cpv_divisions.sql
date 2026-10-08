-- Sectors: one row per CPV division, from the cpv_divisions seed.
-- market groups divisions into 9 markets (seed column), e.g. Digital and data (48, 72).

SELECT
    cpv_division,
    division_name,
    is_digital_and_data,
    market
FROM
    {{ ref('cpv_divisions') }}

UNION ALL

-- Notices without a CPV code, so they don't show as blank in the report
SELECT
    'UNKNOWN',
    'Unknown sector',
    FALSE,
    'Unknown'
