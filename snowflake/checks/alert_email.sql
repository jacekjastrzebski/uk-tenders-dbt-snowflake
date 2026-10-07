-- Check that failure alert emails can reach you: sends a test email, then shows
-- recent deliveries. Sending is asynchronous, so re-run the last query if the
-- test email is not listed yet.
-- Run with: snow sql -c tender -f snowflake/checks/alert_email.sql -D alert_email=<you>

-- Send a test email the same way the alert does
CALL SYSTEM$SEND_EMAIL(
  'TENDER_EMAIL',
  '<% alert_email %>',
  'Find a Tender alert test',
  'Test from TENDER_DB: failure alerts can reach you.'
);

-- Recent emails and whether each was sent (status SUCCESS or FAILURE)
SELECT created, processed, status, error_message
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.NOTIFICATION_HISTORY(INTEGRATION_NAME => 'TENDER_EMAIL'))
ORDER BY created DESC
LIMIT 5;
