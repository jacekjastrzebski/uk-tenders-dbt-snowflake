-- Exploratory queries on the raw Find a Tender data. Read-only.
-- Run in a Snowsight worksheet (role SYSADMIN, warehouse TENDER_WH), or:
--   snow sql -c tender -f snowflake/eda/explore_releases.sql
-- Each raw row is one API page; FLATTEN unpacks it into one row per notice.

-- 1. Notices: total rows, distinct notices, duplicates
WITH notices AS (
    SELECT
        r.value:id::STRING AS notice_id
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)
SELECT
    COUNT(*) AS rows_loaded,
    COUNT(DISTINCT notice_id) AS distinct_notices,
    COUNT(*) - COUNT(DISTINCT notice_id) AS duplicates
FROM
    notices;

-- 2. Tag values and how often they appear (a notice can have several tags)
WITH notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id,
        r.value:tag AS tags
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)
SELECT
    t.value::STRING AS tag,
    COUNT(*) AS notices
FROM
    notices AS n,
    LATERAL FLATTEN(input => n.tags) AS t
GROUP BY
    tag
ORDER BY
    notices DESC;

-- 3. Top buyers by number of notices
WITH notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id,
        r.value:buyer.name::STRING AS buyer
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)
SELECT
    buyer,
    COUNT(*) AS notices
FROM
    notices
GROUP BY
    buyer
ORDER BY
    notices DESC
LIMIT 10;

-- 4. How often tender.value is missing
WITH notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id,
        r.value:tender.value.amount::NUMBER AS tender_value
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)
SELECT
    COUNT(*) AS notices,
    COUNT_IF(tender_value IS NULL) AS missing_value,
    ROUND(100 * COUNT_IF(tender_value IS NULL) / COUNT(*), 1) AS pct_missing
FROM
    notices;

-- 5. One notice in full (click the cell in Snowsight to browse the JSON)
SELECT
    r.value AS notice
FROM
    TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
    LATERAL FLATTEN(input => p.payload:releases) AS r
LIMIT 1;

-- 6. Tags vs Procurement Act notice type (noticeType sits in documents[] at several depths)
WITH notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id,
        ARRAY_TO_STRING(r.value:tag, ',') AS tags,
        r.value AS notice
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
),
notice_types AS (
    SELECT
        n.notice_id,
        n.tags,
        MAX(d.value:noticeType::STRING) AS notice_type
    FROM
        notices AS n,
        LATERAL FLATTEN(input => n.notice, recursive => TRUE) AS d
    WHERE
        d.key = 'documents'
        OR d.path LIKE '%documents[%'
    GROUP BY
        n.notice_id,
        n.tags
)
SELECT
    tags,
    notice_type,
    COUNT(*) AS notices
FROM
    notice_types
GROUP BY
    tags,
    notice_type
ORDER BY
    notices DESC;

-- 7. Field coverage: how many notices have each value, CPV and date field
WITH notices AS (
    SELECT DISTINCT
        r.value:id::STRING AS notice_id,
        r.value AS notice
    FROM
        TENDER_DB.RAW.FIND_A_TENDER_RELEASES AS p,
        LATERAL FLATTEN(input => p.payload:releases) AS r
)
SELECT
    COUNT(*) AS notices,
    COUNT_IF(notice:tender.value.amount IS NOT NULL) AS with_tender_value,
    COUNT_IF(notice:awards[0].value.amount IS NOT NULL) AS with_award_value,
    COUNT_IF(notice:contracts[0].value.amount IS NOT NULL) AS with_contract_value,
    COUNT_IF(notice:tender.classification.id IS NOT NULL) AS with_tender_cpv,
    COUNT_IF(notice:tender.items[0].additionalClassifications[0].id IS NOT NULL) AS with_item_cpv,
    COUNT_IF(notice:tender.tenderPeriod.endDate IS NOT NULL) AS with_closing_date,
    COUNT_IF(ARRAY_SIZE(notice:awards) > 0) AS with_awards,
    MIN(notice:date::TIMESTAMP_TZ) AS earliest,
    MAX(notice:date::TIMESTAMP_TZ) AS latest
FROM
    notices;
