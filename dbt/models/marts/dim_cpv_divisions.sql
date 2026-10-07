-- Sectors: one row per CPV division, from the cpv_divisions seed.
-- market groups divisions into the digital and data market and everything else.

SELECT
    cpv_division,
    division_name,
    is_digital_and_data,
    IFF(is_digital_and_data, 'Digital and data', 'Other') AS market
FROM
    {{ ref('cpv_divisions') }}
