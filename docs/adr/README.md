# Architecture decision records

One file per significant decision: the context, the decision and its consequences. A decision is changed by a new record that supersedes the old one, not by editing it.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-run-ingestion-in-snowflake.md) | Run ingestion inside Snowflake, not on GitHub Actions | Accepted |
| [0002](0002-one-daily-ingest-schedule.md) | One ingest schedule: every 3 hours, 07:00–19:00 UK time, every day | Accepted |
| [0003](0003-failure-alert-by-email.md) | Email on failure with a scheduled alert | Accepted |
| [0004](0004-least-privilege-roles-and-deploy-user.md) | One role per job and a service user for deploys | Accepted |
| [0005](0005-deploy-only-changed-objects.md) | Deploy on merge, only the objects whose files changed | Accepted |
| [0006](0006-loader-constants-in-code.md) | Keep loader constants in code, not a config file | Accepted |
| [0007](0007-classify-notices-by-notice-type.md) | Classify notices by `noticeType`, not `tag` | Accepted |
| [0008](0008-dbt-environments-and-staging-views.md) | dbt: dev/prod by schema, staging as views | Accepted; views superseded by 0015 |
| [0009](0009-run-dbt-on-a-schedule-in-snowflake.md) | Run dbt in Snowflake, 20 minutes after each load | Proposed |
| [0010](0010-source-freshness-thresholds.md) | Source freshness: warn at 13 h (logged), error at 26 h (email) | Accepted |
| [0011](0011-load-window-overlap.md) | Overlap each load window by 15 minutes | Accepted; time zone risk resolved by 0018 |
| [0012](0012-business-terms-in-staging.md) | Name models in business terms: notices, not releases | Accepted |
| [0015](0015-staging-as-tables.md) | Staging models as tables; layers named raw → staging → marts | Accepted |
| [0016](0016-strip-contact-details-in-staging.md) | Strip contact details from staging, including the stored JSON | Accepted |
| [0017](0017-backfill-from-procurement-act-start.md) | Backfill from 24 February 2025, through the API | Accepted |
| [0018](0018-api-dates-in-uk-local-time.md) | Send API window dates as UK local time | Accepted |
