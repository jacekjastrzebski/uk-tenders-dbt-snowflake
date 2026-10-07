# 0001. Run ingestion inside Snowflake

Status: Accepted (2026-10-07)

## Context
The loader first ran on a GitHub Actions cron. Scheduled Actions runs proved not reliable enough, and the project is also a chance to learn Snowflake-native scheduling. Calling an external API from Snowflake needs external access, which trial accounts block.

## Decision
Upgrade to a paid account and run `ingestion/load_find_a_tender.py` as a Python stored procedure (`LOAD_FIND_A_TENDER_RELEASES`), imported from a stage and called by a serverless task. Outbound traffic is limited to the Find a Tender host by a network rule.

## Consequences
- Runs, logs and alerts all live in Snowflake; GitHub Actions only checks and deploys code.
- Serverless task at SMALL size: billed only while running, a few credits a month.
- The same Python file still runs locally (`uv run ingestion/load_find_a_tender.py`).
- Code reaches Snowflake through a stage upload, so deploys are explicit (see 0005).
