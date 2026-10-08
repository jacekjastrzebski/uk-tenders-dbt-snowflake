# Architecture

How the tracker is built, in pictures: what talks to what, what runs where and when, and who may touch which data. Each diagram links to the decision record (ADR) behind it. Table-level detail is in the ERDs ([staging](diagrams/staging-erd.md), [marts](diagrams/marts-erd.md)); to run your own copy, see [self-hosting.md](self-hosting.md).

| Diagram | Answers |
|---|---|
| [1. System context](#1-system-context-c4-level-1) | Who uses the system, and what it depends on |
| [2. Containers](#2-containers-c4-level-2) | The moving parts and how data flows between them |
| [3. dbt components](#3-dbt-project-components-c4-level-3) | What is inside the dbt project |
| [4. Deployment](#4-deployment-c4) | What runs where |
| [5. Notice to dashboard](#5-swimlane-from-notice-to-dashboard) | The data's journey, lane by lane |
| [6. Change to production](#6-swimlane-from-change-to-production) | How a code change reaches Snowflake |
| [7. One ingest run](#7-sequence-one-ingest-run) | What the loader does, call by call |
| [8. dbt run and alerts](#8-sequence-scheduled-dbt-run-and-failure-alerts) | How dbt runs and how failures reach you |
| [9. Daily schedule](#9-daily-schedule) | When each job runs |
| [10. Layers and grain](#10-data-layers-and-grain) | What one row means at each layer |
| [11. dbt lineage](#11-dbt-lineage) | Which model reads which |
| [12. Roles and access](#12-roles-and-access) | Who can read or change what |
| [13. Task states](#13-task-and-alert-states) | How scheduled jobs start, fail and stop |
| [14. Procurement lifecycle](#14-procurement-lifecycle-in-the-model) | Which notice fills which fact column |

Diagrams are [Mermaid](https://mermaid.js.org), so GitHub renders them and changes are reviewed as text. The C4 ones follow the [C4 model](https://c4model.com): context, containers, components, deployment.

## 1. System context (C4 level 1)

```mermaid
C4Context
    title System context: UK tenders tracker

    Person(analyst, "Analyst / bid team", "Looks for open tenders, buyers, winners and award times")
    Person(developer, "Developer", "Changes the loader, dbt models and report")

    System(tracker, "UK tenders tracker", "Loads Find a Tender notices into Snowflake, models them with dbt, reports in Power BI")

    System_Ext(fat, "Find a Tender API", "UK government OCDS API: every Procurement Act notice")
    System_Ext(github, "GitHub", "Code, pull requests, CI and deploys (Actions)")
    System_Ext(email, "Email", "Failure alerts")

    Rel(tracker, fat, "Fetches notices updated since the last run", "HTTPS, JSON")
    Rel(analyst, tracker, "Reads the report", "Power BI")
    Rel(developer, github, "Pushes changes", "git")
    Rel(github, tracker, "Tests, then deploys merged changes", "Snowflake CLI")
    Rel(tracker, email, "Sends an email when a run fails")
    Rel(email, developer, "Alerts")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

One external data source, one platform (Snowflake) doing all the work, and GitHub as the only way changes reach it ([ADR 0001](adr/0001-run-ingestion-in-snowflake.md), [ADR 0019](adr/0019-deploy-after-ci-checks.md)).

## 2. Containers (C4 level 2)

```mermaid
C4Container
    title Containers: UK tenders tracker

    System_Ext(fat, "Find a Tender API", "OCDS release packages")
    System_Ext(github, "GitHub Actions", "ci.yml, deploy.yml")
    System_Ext(email, "Email")

    Boundary(snowflake, "Snowflake account: TENDER_DB", "Snowflake") {
        Container(ingest, "Ingest task and loader", "Serverless task, Python stored procedure", "Fetches new notices every 3 hours")
        ContainerDb(raw, "RAW", "Tables", "API pages unchanged; one row per loader run")
        Container(dbt, "dbt project and task", "dbt project object, task on TENDER_WH", "Builds the models 20 minutes after each load")
        ContainerDb(staging, "PROD_STAGING, PROD_INTERMEDIATE", "Tables, views, seeds", "Deduplicated, typed notices; awards across notices")
        ContainerDb(marts, "PROD_MARTS", "Tables", "Star schema: 2 facts, 4 dimensions")
        Container(alerts, "Failure alerts", "Snowflake alerts", "RAW.INGEST_FIND_A_TENDER_FAILED, DBT.RUN_DBT_FAILED")
    }

    Boundary(powerbi, "Power BI", "Desktop and Service") {
        Container(model, "Semantic model", "TMDL, import mode", "Tables, relationships, DAX measures")
        Container(report, "Report", "PBIR", "Four pages, one per question")
    }

    Boundary(users, "Users", "People") {
        Person(analyst, "Analyst")
    }

    Rel(ingest, fat, "GET pages", "HTTPS")
    Rel(ingest, raw, "INSERT pages, log run")
    Rel(dbt, raw, "Reads")
    Rel(dbt, staging, "Builds")
    Rel(dbt, marts, "Builds, grants SELECT")
    Rel(model, marts, "Imports", "Snowflake connector, TENDER_REPORTER")
    Rel(report, model, "Queries")
    Rel(analyst, report, "Reads")
    Rel(alerts, email, "Sends")
    Rel(github, ingest, "Deploys loader, procedure, task")
    Rel(github, dbt, "Deploys project, task")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

- The loader is plain Python, deployed to a stage and run as a stored procedure, so no server of our own runs anything ([ADR 0001](adr/0001-run-ingestion-in-snowflake.md)).
- dbt runs inside Snowflake as a dbt project object, on a schedule, not triggered by the load ([ADR 0009](adr/0009-run-dbt-on-a-schedule-in-snowflake.md)).
- Power BI reads only `PROD_MARTS`, through a read-only role ([ADR 0023](adr/0023-star-schema-for-power-bi.md), [ADR 0024](adr/0024-prod-schema-prefix.md)).

## 3. dbt project components (C4 level 3)

```mermaid
C4Component
    title Components: dbt project UK_TENDERS

    ContainerDb(raw, "RAW", "Snowflake tables", "find_a_tender_releases, find_a_tender_ingest_runs")

    Container_Boundary(project, "dbt project") {
        Component(sources, "Sources", "_find_a_tender__sources.yml", "Freshness: warn 13 h, error 26 h")
        Component(staging, "Staging models", "5 tables", "notices, parties, awards, award_suppliers, contracts; no contact details")
        Component(seeds, "Seeds", "CSV", "hmrc_exchange_rates, cpv_divisions")
        Component(intermediate, "int_awards", "View", "One row per award across notices, value in GBP")
        Component(macro, "normalise_org_name", "Macro", "Groups buyer and supplier names; removes lot numbers")
        Component(marts, "Marts", "6 tables", "fct_procurements, fct_award_suppliers, dim_dates, dim_buyers, dim_suppliers, dim_cpv_divisions")
        Component(tests, "Tests", "Generic and singular", "unique, not_null, relationships; no contact points; values fully allocated")
    }

    Rel(sources, raw, "Declares")
    Rel(staging, sources, "Reads")
    Rel(intermediate, staging, "Reads")
    Rel(intermediate, seeds, "Converts with")
    Rel(marts, intermediate, "Reads")
    Rel(marts, staging, "Reads")
    Rel(marts, macro, "Uses")
    Rel(tests, marts, "Check")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

Layers and conventions: [dbt.md](dbt.md). Rules behind the facts: [ADR 0020](adr/0020-convert-amounts-to-gbp-with-hmrc-rates.md) (GBP), [ADR 0021](adr/0021-keep-supplier-names.md) (names), [ADR 0022](adr/0022-award-fact-rules.md) (award fact).

## 4. Deployment (C4)

```mermaid
C4Deployment
    title Deployment: what runs where

    Deployment_Node(laptop, "Developer computer", "Linux or WSL") {
        Container(uv, "uv, Python 3.14", "pytest, mypy, pre-commit")
        Container(dbtdev, "dbt (local)", "dbt-core 1.12, target dev", "Builds DEV_* schemas")
        Container(snowcli, "Snowflake CLI", "snow", "Runs setup scripts")
    }

    Deployment_Node(gh, "GitHub", "github.com") {
        Deployment_Node(runner, "Hosted runner", "ubuntu-latest") {
            Container(ci, "CI and deploy", "GitHub Actions", "Checks, then snow stage copy, snow sql, snow dbt deploy")
        }
    }

    Deployment_Node(sf, "Snowflake", "Paid account, cloud region of your choice") {
        Deployment_Node(serverless, "Serverless compute", "SMALL") {
            Container(proc, "Loader procedure", "Python 3.14, Snowpark")
        }
        Deployment_Node(wh, "TENDER_WH", "X-SMALL warehouse, suspends after 60 s") {
            Container(dbtprod, "dbt project object", "dbt 1.12.3, target prod")
        }
        Deployment_Node(storage, "TENDER_DB", "Database") {
            ContainerDb(schemas, "RAW, PROD_STAGING, PROD_INTERMEDIATE, PROD_MARTS, DBT", "Schemas")
        }
    }

    Deployment_Node(win, "Windows computer", "Windows 10 or 11") {
        Container(desktop, "Power BI Desktop", "Opens powerbi/UkTenders.pbip")
    }

    Deployment_Node(service, "Power BI Service", "app.powerbi.com") {
        Container(published, "Published report", "Scheduled refresh")
    }

    Rel(snowcli, schemas, "Setup scripts")
    Rel(dbtdev, schemas, "DEV_*")
    Rel(ci, proc, "Deploys")
    Rel(ci, dbtprod, "Deploys")
    Rel(desktop, schemas, "Imports PROD_MARTS")
    Rel(published, schemas, "Refreshes from PROD_MARTS")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

The ingest task is serverless (billed per second of compute); dbt projects can't run serverless, so the dbt task uses `TENDER_WH`. Power BI talks to Snowflake directly from the cloud; no on-premises data gateway is needed.

## 5. Swimlane: from notice to dashboard

```mermaid
flowchart LR
    subgraph L1["Buyer and Find a Tender"]
        A1["Buyer publishes a notice<br/>UK4 tender, UK6 award, ..."] --> A2["API serves it as<br/>an OCDS release"]
    end
    subgraph L2["Ingest task, every 3 h"]
        B1["Fetch releases updated<br/>since the last run"] --> B2["Store each page<br/>unchanged in RAW"]
    end
    subgraph L3["dbt task, 20 min later"]
        C1["Check source<br/>freshness"] --> C2["Staging: deduplicate,<br/>flatten, strip contacts"]
        C2 --> C3["Intermediate: one row<br/>per award, in GBP"] --> C4["Marts: star schema"] --> C5["Tests"]
    end
    subgraph L4["Power BI"]
        D1["Scheduled refresh<br/>imports the marts"] --> D2["Measures and pages"]
    end
    subgraph L5["Analyst"]
        E1["What's open? Who's buying?<br/>Who's winning? How long?"]
    end
    A2 -->|"up to 3 h"| B1
    B2 -->|"20 min"| C1
    C5 -->|"next refresh"| D1
    D2 --> E1
```

A notice reaches the report within about 3½ hours by day, 12 hours overnight, plus the Power BI refresh interval. Lanes are owners: each one only reads what the lane before it wrote.

## 6. Swimlane: from change to production

```mermaid
flowchart TB
    subgraph DEV["Developer"]
        D1["Branch and change code"] --> D2["pre-commit: file checks,<br/>mypy, pytest"] --> D3["Open pull request"]
        D5["Merge to main"]
    end
    subgraph CI["GitHub CI (ci.yml)"]
        C1["Checks on the PR:<br/>pre-commit, mypy strict, pytest"]
        C2["Same checks on main"]
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

    D3 --> C1 -->|"green"| D5 --> C2 -->|"green"| P1
    C1 -->|"red"| D1
    P1 -->|"ingestion/load_find_a_tender.py"| P2
    P1 -->|"native_ingestion/02-04"| P3
    P1 -->|"dbt/** or profiles.yml"| P4
    P1 -->|"snowflake/dbt/01_run_dbt_task.sql"| P5
    P2 & P3 & P4 & P5 --> S1
```

Only objects whose files changed are redeployed ([ADR 0005](adr/0005-deploy-only-changed-objects.md)), and only after the checks pass ([ADR 0019](adr/0019-deploy-after-ci-checks.md)). A manual run, or a change to `deploy.yml` itself, deploys everything. One-off setup that needs ACCOUNTADMIN stays manual.

## 7. Sequence: one ingest run

```mermaid
sequenceDiagram
    autonumber
    participant T as Task<br/>RAW.INGEST_FIND_A_TENDER
    participant P as Procedure<br/>LOAD_FIND_A_TENDER_RELEASES
    participant R as RAW.FIND_A_TENDER_INGEST_RUNS
    participant API as Find a Tender API
    participant F as RAW.FIND_A_TENDER_RELEASES

    T->>P: CALL (cron 07, 10, 13, 16, 19 UK time)
    P->>P: check connection sets database and warehouse
    P->>R: MAX(window_to) WHERE status = 'success'
    R-->>P: last end (none: look back 3 h)
    Note over P: window = last end − 15 min → now (ADR 0011)<br/>sent as UK local time (ADR 0018)
    loop each page, following links.next
        P->>API: GET ocdsReleasePackages?updatedFrom&updatedTo&limit=100
        alt 429 or 5xx
            API-->>P: Retry-After
            P->>API: retry (up to 10 times)
        end
        API-->>P: page: up to 100 releases
        P->>F: INSERT page unchanged (run_id, page_number, payload)
        Note over P: pause 0.5 s, and if a next link repeats,<br/>split the window in half and fetch each
    end
    alt every page saved
        P->>R: log run: success, pages, releases
    else error
        P->>R: log run: failed, error_message
        P-->>T: raise (task run fails)
    end
    P-->>T: "Run …: N releases in M pages"
```

A failed run doesn't move the watermark, so the next run fetches the same window again; duplicates from overlap and retries are removed in staging. Backfill uses the same `load_window`, one UTC day per run ([ADR 0017](adr/0017-backfill-from-procurement-act-start.md)).

## 8. Sequence: scheduled dbt run and failure alerts

```mermaid
sequenceDiagram
    autonumber
    participant DT as Task DBT.RUN_DBT
    participant DP as dbt project<br/>DBT.UK_TENDERS
    participant DB as TENDER_DB
    participant IA as Alert<br/>RAW.INGEST_FIND_A_TENDER_FAILED
    participant DA as Alert<br/>DBT.RUN_DBT_FAILED
    participant M as Email (TENDER_EMAIL)

    Note over DT: :20 past 07, 10, 13, 16, 19
    DT->>DP: source freshness --target prod
    DP->>DB: MAX(loaded_at) in RAW
    alt raw data older than 26 h
        DP-->>DT: error: task fails, nothing rebuilt
    else fresh (warning logged after 13 h)
        DT->>DP: build --target prod
        DP->>DB: seeds, staging, intermediate, marts, tests
        DP->>DB: GRANT SELECT on marts TO TENDER_REPORTER
        DP-->>DT: success (about 70 s)
    end
    Note over IA: :30 past
    IA->>DB: TASK_HISTORY errors for INGEST_* in the last 3 h
    opt any
        IA->>M: "Find a Tender ingest failed"
    end
    Note over DA: :50 past
    DA->>DB: TASK_HISTORY errors for RUN_DBT in the last 3 h
    opt any
        DA->>M: "Find a Tender dbt run failed"
    end
```

Each check looks back 3 hours, the gap between runs, so a failure is emailed once ([ADR 0003](adr/0003-failure-alert-by-email.md), [ADR 0010](adr/0010-source-freshness-thresholds.md)).

## 9. Daily schedule

One cycle, repeated at 07:00, 10:00, 13:00, 16:00 and 19:00 UK time (Europe/London, so it follows BST) every day ([ADR 0002](adr/0002-one-daily-ingest-schedule.md)). Durations are typical runs in October 2026.

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
    Scheduled refresh (suggested)     :pbi, 08:00:00, 5m
```

The 20-minute gap leaves room for a slow load (the task times out at 15 minutes). Power BI Service schedules refreshes on the hour or half hour, so 08:00, 11:00, 14:00, 17:00 and 20:00 pick up each build.

## 10. Data layers and grain

```mermaid
flowchart TB
    API["Find a Tender API<br/>OCDS release packages"]
    subgraph RAW["RAW: tables, loaded by the procedure"]
        R1["FIND_A_TENDER_RELEASES<br/>1 row = 1 API page (≤ 100 notices)"]
        R2["FIND_A_TENDER_INGEST_RUNS<br/>1 row = 1 loader run"]
    end
    subgraph STG["PROD_STAGING: tables"]
        S1["notices: 1 row = 1 notice, latest copy"]
        S2["parties: 1 per organisation in a notice"]
        S3["awards: 1 per award in a notice"]
        S4["award_suppliers: 1 per supplier on an award"]
        S5["contracts: 1 per contract in a notice"]
        S6["seeds: exchange rates, CPV divisions"]
    end
    subgraph INT["PROD_INTERMEDIATE: views"]
        I1["int_awards: 1 row = 1 award<br/>across all its notices, in GBP"]
    end
    subgraph MARTS["PROD_MARTS: tables, star schema"]
        F1["fct_procurements<br/>1 row = 1 Procurement Act tender"]
        F2["fct_award_suppliers<br/>1 row = 1 supplier on an award"]
        DIM["dim_dates · dim_buyers ·<br/>dim_suppliers · dim_cpv_divisions"]
    end
    API --> R1
    R1 --> S1 --> S2 & S3 & S4 & S5
    S3 & S4 & S5 & S6 --> I1
    S1 --> F1
    I1 --> F2
    S1 & S4 & S6 --> DIM
```

Staging keeps one row per notice, so the same award shows up in several notices; deduplication happens once, in `int_awards`, before anything is summed ([ADR 0015](adr/0015-staging-as-tables.md), [ADR 0012](adr/0012-business-terms-in-staging.md)).

## 11. dbt lineage

Every model, seed and source, as `dbt docs` draws it. Test models are left out.

```mermaid
flowchart LR
    classDef source fill:#eef,stroke:#669
    classDef seed fill:#efe,stroke:#696
    classDef mart fill:#fee,stroke:#966

    raw_rel[("raw.find_a_tender_releases")]:::source
    raw_runs[("raw.find_a_tender_ingest_runs")]:::source
    hmrc["hmrc_exchange_rates"]:::seed
    cpv["cpv_divisions"]:::seed

    notices["stg_find_a_tender__notices"]
    parties["stg_find_a_tender__parties"]
    awards["stg_find_a_tender__awards"]
    award_sup["stg_find_a_tender__award_suppliers"]
    contracts["stg_find_a_tender__contracts"]
    int_awards["int_awards"]

    fct_proc["fct_procurements"]:::mart
    fct_aws["fct_award_suppliers"]:::mart
    dim_dates["dim_dates"]:::mart
    dim_buyers["dim_buyers"]:::mart
    dim_sup["dim_suppliers"]:::mart
    dim_cpv["dim_cpv_divisions"]:::mart

    raw_rel --> notices
    notices --> parties & awards & award_sup & contracts
    notices & awards & award_sup & contracts & hmrc --> int_awards
    notices --> fct_proc
    int_awards & awards & award_sup --> fct_aws
    notices --> dim_buyers
    notices & award_sup --> dim_sup
    cpv --> dim_cpv
```

`raw.find_a_tender_ingest_runs` is declared for freshness only; no model reads it. `dim_dates` is generated from project variables, not read from a table.

## 12. Roles and access

```mermaid
flowchart LR
    subgraph Users
        you["You (person)"]
        deploy["TENDER_DEPLOY<br/>service user, key pair"]
        pbi["Power BI user<br/>TENDER_REPORTER only"]
    end
    subgraph Roles
        sysadmin["SYSADMIN"]
        ingest["TENDER_INGEST"]
        transform["TENDER_TRANSFORM"]
        reporter["TENDER_REPORTER"]
    end
    subgraph Objects["TENDER_DB and account objects"]
        raw["RAW tables<br/>releases, ingest runs"]
        rawobj["RAW procedure, task, alert,<br/>CODE_STAGE"]
        api["FIND_A_TENDER_API_ACCESS<br/>(egress to one host)"]
        mail["TENDER_EMAIL"]
        dbtobj["DBT schema: project, task, alert"]
        built["PROD_/DEV_ STAGING,<br/>INTERMEDIATE, MARTS"]
        marts["PROD_MARTS, DEV_MARTS"]
        wh["TENDER_WH"]
    end

    you --> sysadmin & transform & reporter
    deploy --> ingest & transform
    pbi --> reporter
    sysadmin -.->|inherits| ingest & transform & reporter

    ingest -->|"SELECT, INSERT"| raw
    ingest -->|owns| rawobj
    ingest -->|uses| api & mail
    transform -->|SELECT| raw
    transform -->|owns| dbtobj & built
    transform -->|uses| mail
    reporter -->|SELECT| marts
    ingest & transform & reporter -->|uses| wh
```

One role per job, each with only what that job needs ([ADR 0004](adr/0004-least-privilege-roles-and-deploy-user.md)). Grants live in `snowflake/setup/03–04`, `snowflake/native_ingestion/01_external_access.sql` and `snowflake/dbt/00_dbt_setup.sql`; mart `SELECT` is re-granted by dbt on every build. Snowflake activates a user's secondary roles too, so the Power BI user should hold `TENDER_REPORTER` and nothing else.

## 13. Task and alert states

```mermaid
stateDiagram-v2
    [*] --> Suspended: CREATE OR REPLACE TASK / ALERT
    Suspended --> Started: ALTER ... RESUME (in the same script)
    Started --> Running: schedule fires, or EXECUTE TASK
    Running --> Started: succeeded
    Running --> Failed: error or timeout (15 min ingest, 30 min dbt)
    Failed --> Started: next schedule
    Failed --> Suspended: 3 failures in a row
    Suspended --> Started: fix, then ALTER TASK ... RESUME
```

Alerts (`INGEST_FIND_A_TENDER_FAILED`, `RUN_DBT_FAILED`) have only Suspended and Started: each check either sends an email or does nothing. A redeploy recreates a task and resumes it, which also clears a suspension after 3 failures.

## 14. Procurement lifecycle in the model

Which notices fill which columns of `FCT_PROCUREMENTS` (one row per procurement with a UK4 tender) and `FCT_AWARD_SUPPLIERS`. Notice types are explained in the [procurement primer](procurement-primer.md#4-procurement-act-notice-types).

```mermaid
stateDiagram-v2
    direction LR
    state "Open to bid" as Open
    state "Awarded" as Awarded
    state "Contract signed" as Signed
    state "Cancelled" as Cancelled

    [*] --> Open: UK4 tender<br/>tender_published_date, closing_date
    Open --> Open: UK4 update<br/>latest closing_date
    Open --> Awarded: UK6 award<br/>award_published_date, award rows
    Open --> Signed: UK7 without UK6<br/>award_published_date = contract date
    Awarded --> Signed: UK7 details<br/>contract_published_date, contract value
    Open --> Cancelled: UK12, no award<br/>is_cancelled
    Signed --> [*]
    Cancelled --> [*]
```

- "Open" is decided in Power BI at query time (closing date from today, no award, not cancelled), so it never goes stale between refreshes.
- `days_tender_to_award` and `days_award_to_contract` are the gaps between these dates.
- Awards without a UK4 (direct awards via UK5, framework call-offs) appear in `FCT_AWARD_SUPPLIERS` but not in `FCT_PROCUREMENTS`.

## Quality gates

| Gate | Where | Stops |
|---|---|---|
| pre-commit: private keys, YAML/TOML, mypy strict, pytest | Each commit, and CI | Broken Python, committed keys |
| CI must pass before deploy | `ci.yml` → `deploy.yml` | Untested code reaching Snowflake |
| Source freshness: warn 13 h, error 26 h | First step of `RUN_DBT` | Rebuilding marts on stale data |
| dbt tests: keys, relationships, singular tests | `dbt build` | Bad rows going unnoticed: a failing test fails the build |
| Failure alerts | `:30` and `:50` past each run | Silent failures |

## Security and privacy

- Buyer contact details are personal data: they stay in `RAW` and are stripped from staging, including the stored JSON; a dbt test enforces it ([ADR 0016](adr/0016-strip-contact-details-in-staging.md)).
- Key-pair login for people and the deploy user; the private key lives in a GitHub secret, never in the repo (pre-commit `detect-private-key`).
- The loader can reach one host only (network rule `FIND_A_TENDER_API_RULE`).
- The data itself is public, under the Open Government Licence v3.0.

## Known gaps

Open items and their priority are in the [DataOps review](plans/dataops-review.md); the README lists what's done and what's next.
