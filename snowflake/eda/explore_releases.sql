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
