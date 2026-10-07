-- One row per organisation named in a notice (buyer, supplier, review body).
-- contactPoint (names, emails, phone numbers) is personal data and left out.
-- Keyed by position: a party id can appear more than once in a notice (one
-- organisation in two roles, branches sharing a company number, publisher errors).

SELECT
    n.notice_id || '/' || p.index AS party_key,
    n.notice_id,
    n.ocid,
    p.value:id::STRING AS party_id,
    p.value:name::STRING AS party_name,
    p.value:roles AS roles,
    p.value:address.locality::STRING AS locality,
    p.value:address.region::STRING AS region,
    p.value:address.postalCode::STRING AS postcode,
    p.value:address.countryName::STRING AS country
FROM
    {{ ref('stg_find_a_tender__notices') }} AS n,
    LATERAL FLATTEN(input => n.notice:parties) AS p
