# Flows

How data and changes move through the system, and when. Swimlanes have one box per owner; sequence diagrams read top to bottom, one column per part, with `alt` boxes for either/or paths and `loop` boxes for repeats. Overview: [architecture.md](../architecture.md).

## Notice to dashboard

The data's journey, one lane per owner; each lane only reads what the lane before it wrote. A notice reaches the marts within about 3½ hours by day and 12 hours overnight, and the report at its next refresh.

```mermaid
flowchart TB
    subgraph L1["Buyer and Find a Tender"]
        direction LR
        A1["Buyer publishes a notice<br/>UK4 tender, UK6 award, ..."] --> A2["API serves it as<br/>an OCDS release"]
    end
    subgraph L2["Ingest task, every 3 hours"]
        direction LR
        B1["Fetch releases updated<br/>since the last run"] --> B2["Store each page<br/>unchanged in RAW"]
    end
    subgraph L3["dbt task, 20 minutes later"]
        direction LR
        C1["Check source<br/>freshness"] --> C2["Staging: deduplicate,<br/>flatten, strip contacts"] --> C3["Intermediate: one row<br/>per award, in GBP"] --> C4["Marts: star schema"] --> C5["Tests"]
    end
    subgraph L4["Power BI"]
        direction LR
        D1["Scheduled refresh<br/>imports the marts"] --> D2["Measures and pages"]
    end
    subgraph L5["Analyst"]
        direction LR
        E1["What's open? Who's buying?<br/>Who's winning? How long?"]
    end
    L1 -->|"up to 3 h"| L2 -->|"20 min"| L3 -->|"next refresh"| L4 --> L5
```

## Daily schedule

One cycle, repeated at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time (Europe/London, so it follows BST), every day ([ADR 0002](../adr/0002-one-daily-ingest-schedule.md)). Bars are jobs, diamonds are alert checks; durations are typical runs in October 2026.

```mermaid
gantt
    title One cycle (starts at 07, 10, 13, 16, 19)
    dateFormat HH:mm:ss
    axisFormat %H:%M

    section Ingest
    Load from API (about 25 s)        :ingest, 07:00:00, 1m
    Ingest failure alert              :milestone, 07:30:00, 0m
    section dbt
    Freshness and build (about 70 s)  :dbt, 07:20:00, 2m
    dbt failure alert                 :milestone, 07:50:00, 0m
    section Power BI
    Scheduled refresh                 :pbi, 08:00:00, 5m
    Refresh missed alert              :milestone, 09:30:00, 0m
```

The 20-minute gap leaves room for a slow load (the ingest task times out at 15 minutes). Power BI Service schedules refreshes on the hour or half hour, so the refresh is set for 08:00, 11:00, 14:00, 17:00 and 20:00, picking up each build. 90 minutes later a Snowflake alert emails if Power BI didn't read the marts ([ADR 0031](../adr/0031-alert-when-power-bi-stops-refreshing.md)).

## One ingest run

What the loader does in one scheduled run. A failed run doesn't move the watermark, so the next run fetches the same window again; duplicates from the overlap and retries are removed in staging. The backfill uses the same steps, one UTC day per run ([ADR 0017](../adr/0017-backfill-from-procurement-act-start.md)).

```mermaid
sequenceDiagram
    autonumber
    participant T as Task<br/>RAW.INGEST_FIND_A_TENDER
    participant P as Procedure<br/>LOAD_FIND_A_TENDER_RELEASES
    participant R as RAW.FIND_A_TENDER_INGEST_RUNS
    participant API as Find a Tender API
    participant F as RAW.FIND_A_TENDER_RELEASES

    T->>P: CALL (cron 07, 10, 13, 16, 19 UK time)
    P->>P: check the connection sets database and warehouse
    P->>R: MAX(window_to) WHERE status = 'success'
    R-->>P: last end (none: look back 3 h)
    Note over P: window = last end − 15 min → now (ADR 0011),<br/>sent as UK local time (ADR 0018)
    loop each page, following links.next
        P->>API: GET ocdsReleasePackages?updatedFrom&updatedTo&limit=100
        alt 429 or 503
            API-->>P: error with Retry-After
            P->>API: wait that long, then retry
        else 500, 502 or 504
            API-->>P: error
            P->>API: back off, waiting longer each time, then retry
        end
        Note over P,API: up to 10 retries per request
        API-->>P: page: up to 100 releases
        P->>F: INSERT page unchanged (run_id, page_number, payload)
        Note over P: pause 0.5 s, and if a next link repeats,<br/>split the window in half and fetch each half
    end
    alt every page saved
        P->>R: log run: success, pages, releases
    else error
        P->>R: log run: failed, error_message
        P-->>T: raise, so the task run fails
    end
    P-->>T: "Run …: N releases in M pages"
```

## dbt run and failure alerts

How dbt runs after each load, and how a failure of either job reaches you. Each alert looks back 3 hours, the gap between runs, so a failure is emailed once ([ADR 0003](../adr/0003-failure-alert-by-email.md), [ADR 0010](../adr/0010-source-freshness-thresholds.md)).

```mermaid
sequenceDiagram
    autonumber
    participant DT as Task DBT.RUN_DBT
    participant DP as dbt project<br/>DBT.UK_TENDERS
    participant DB as TENDER_DB
    participant IA as Alert<br/>RAW.INGEST_FIND_A_TENDER_FAILED
    participant DA as Alert<br/>DBT.RUN_DBT_FAILED
    participant M as Email (TENDER_EMAIL)

    Note over DT: 20 past 07, 10, 13, 16, 19
    DT->>DP: source freshness --target prod
    DP->>DB: MAX(loaded_at) in RAW
    alt raw data older than 26 h
        DP-->>DT: freshness error, meant to fail the task before the build
    else fresh (a warning is logged after 13 h)
        DT->>DP: build --target prod
        DP->>DB: seeds, staging, intermediate, marts, tests
        DP->>DB: GRANT SELECT on marts TO TENDER_REPORTER
        DP-->>DT: success (about 70 s)
    end
    Note over IA: 30 past
    IA->>DB: TASK_HISTORY errors for INGEST_* in the last 3 h
    opt any
        IA->>M: "Find a Tender ingest failed"
    end
    Note over DA: 50 past
    DA->>DB: TASK_HISTORY errors for RUN_DBT in the last 3 h
    opt any
        DA->>M: "Find a Tender dbt run failed"
    end
```

Whether a freshness error stops the task before the build is still to be confirmed once in Snowflake ([dbt.md → Runs in Snowflake](../dbt.md#runs-in-snowflake)).

## Change to production

How a code change reaches Snowflake, one lane per owner. Only objects whose files changed are redeployed ([ADR 0005](../adr/0005-deploy-only-changed-objects.md)), and only after the checks pass ([ADR 0019](../adr/0019-deploy-after-ci-checks.md)); pull requests that change dbt also build and test it in throwaway schemas ([ADR 0030](../adr/0030-build-dbt-in-ci.md)). A manual run, or a change to `deploy.yml` itself, deploys everything. One-off setup that needs ACCOUNTADMIN stays manual.

```mermaid
flowchart TB
    subgraph DEV["Developer"]
        D1["Branch and change code"] --> D2["pre-commit: file checks,<br/>mypy, pytest"] --> D3["Open pull request"]
        D5["Merge to main"]
    end
    subgraph CI["GitHub CI (ci.yml)"]
        C1["Checks on the PR:<br/>pre-commit, mypy strict, pytest,<br/>dbt parse"]
        C3["dbt build into CI_PR_&lt;n&gt;_* schemas,<br/>then drop them (PRs changing dbt/)"]
        C2["Same checks and dbt parse on main"]
    end
    subgraph DEP["Deploy (deploy.yml)"]
        P1{"Which files changed?"}
        P2["Upload loader to CODE_STAGE"]
        P3["Recreate procedure / task / alert"]
        P4["snow dbt deploy UK_TENDERS"]
        P5["Recreate RUN_DBT task and alert"]
    end
    subgraph SF["Snowflake"]
        S1["Next scheduled run<br/>uses the new version"]
    end

    D3 --> C1 & C3
    C1 & C3 -->|"green"| D5 --> C2 -->|"green"| P1
    C1 & C3 -->|"red"| D1
    P1 -->|"ingestion/load_find_a_tender.py"| P2
    P1 -->|"native_ingestion/02-04"| P3
    P1 -->|"dbt/** or profiles.yml"| P4
    P1 -->|"snowflake/dbt/01_run_dbt_task.sql"| P5
    P2 & P3 & P4 & P5 --> S1
```
