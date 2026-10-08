-- Email if Power BI stops refreshing (ADR 0031). Power BI Service only emails addresses
-- inside its own tenant, so this alert watches from the Snowflake side: Power BI refreshes
-- at 08:00, 11:00, 14:00, 17:00 and 20:00 UK time as TENDER_POWERBI, and reads the marts
-- on TENDER_WH. 90 minutes after each refresh, no successful Power BI query in the last
-- 100 minutes means the refresh failed or didn't run.
-- Needs MONITOR on TENDER_WH for TENDER_TRANSFORM (snowflake/dbt/00_dbt_setup.sql).
-- Deployed by .github/workflows/deploy.yml, filling in the recipient. By hand:
--   snow sql -f snowflake/powerbi/01_refresh_alert.sql -D alert_email=<you> -c tender
USE ROLE TENDER_TRANSFORM;

CREATE OR REPLACE ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED
  SCHEDULE = 'USING CRON 30 9,12,15,18,21 * * * Europe/London'
  -- alerts only accept IF (EXISTS (...)): a row comes back when Power BI ran no queries
  IF (EXISTS (
    SELECT 1
    FROM (
      SELECT COUNT(*) AS powerbi_queries
      FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.QUERY_HISTORY_BY_WAREHOUSE(
        WAREHOUSE_NAME => 'TENDER_WH',
        END_TIME_RANGE_START => DATEADD('minute', -100, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 10000))
      WHERE user_name = 'TENDER_POWERBI'
        AND execution_status = 'SUCCESS'
        AND query_text NOT ILIKE 'SHOW%'
    )
    WHERE powerbi_queries = 0
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'TENDER_EMAIL',
      '<% alert_email %>',
      'Power BI report did not refresh',
      'Power BI has not read the marts since its last scheduled refresh. Check the UkTenders semantic model in Power BI Service: Settings > Refresh > View refresh history, and its data source credentials (TENDER_POWERBI, key pair).'
    );

-- Alerts are created suspended
ALTER ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED RESUME;

-- Check it once now instead of waiting for the schedule:
--   EXECUTE ALERT TENDER_DB.DBT.POWERBI_REFRESH_MISSED;
--   SELECT * FROM TABLE(TENDER_DB.INFORMATION_SCHEMA.ALERT_HISTORY()) ORDER BY scheduled_time DESC;
