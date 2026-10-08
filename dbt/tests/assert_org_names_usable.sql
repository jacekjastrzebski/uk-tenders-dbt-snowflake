-- Every buyer and supplier shown in the marts must have a name that can
-- identify it: staging replaces unusable names (macro is_unusable_org_name,
-- docs/adr/0025-replace-unusable-organisation-names.md).

SELECT
    'buyer' AS organisation_type,
    buyer_key AS organisation_key,
    buyer_name AS organisation_name
FROM
    {{ ref('dim_buyers') }}
WHERE
    {{ is_unusable_org_name('buyer_name') }}

UNION ALL

SELECT
    'supplier',
    supplier_key,
    supplier_name
FROM
    {{ ref('dim_suppliers') }}
WHERE
    {{ is_unusable_org_name('supplier_name') }}
