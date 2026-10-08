# Security

Who can read or change what. Overview: [architecture.md](../architecture.md).

## Roles and access

Read left to right: users hold roles, roles have privileges on objects. Solid arrows are grants; dotted arrows mean a role inherits another (SYSADMIN can do whatever the other roles can). One role per job, each with only what that job needs ([ADR 0004](../adr/0004-least-privilege-roles-and-deploy-user.md)).

```mermaid
flowchart LR
    subgraph Users
        you["You (person)"]
        deploy["TENDER_DEPLOY<br/>service user, key pair"]
        ciuser["TENDER_CI<br/>service user, key pair"]
        powerbi["TENDER_POWERBI<br/>service user, key pair"]
        guest["Guest (person, password)"]
    end
    subgraph Roles
        sysadmin["SYSADMIN"]
        ingest["TENDER_INGEST<br/>loads"]
        transform["TENDER_TRANSFORM<br/>models"]
        reporter["TENDER_REPORTER<br/>reads marts"]
        cirole["TENDER_CI<br/>builds pull requests"]
        viewer["TENDER_VIEWER<br/>guest, reads RAW and PROD_*"]
    end
    subgraph Objects["Objects"]
        base["TENDER_DB, TENDER_WH"]
        raw["RAW tables"]
        stage["CODE_STAGE"]
        rawobj["RAW procedures, task, alert"]
        integrations["FIND_A_TENDER_API_ACCESS,<br/>TENDER_EMAIL"]
        dbtobj["DBT schema:<br/>project, task, alerts"]
        built["PROD_* and DEV_* schemas"]
        cischemas["CI_PR_* schemas<br/>(dropped after each build)"]
        marts["PROD_MARTS, DEV_MARTS"]
        structure["All schemas, tables, views<br/>(structure only)"]
        tasks["All tasks"]
        guestdata["RAW, PROD_STAGING,<br/>PROD_INTERMEDIATE, PROD_MARTS"]
        guestwh["TENDER_VIEWER_WH<br/>capped at 1 credit a month"]
    end

    you --> sysadmin & transform & reporter
    deploy --> ingest & transform
    ciuser --> cirole
    powerbi --> reporter
    guest --> viewer
    sysadmin -.-> ingest & transform & reporter & viewer & cirole

    sysadmin -->|owns| base & raw & stage
    ingest -->|"SELECT, INSERT"| raw
    ingest -->|"READ, WRITE"| stage
    ingest -->|owns| rawobj
    ingest -->|uses| integrations
    transform -->|SELECT| raw
    transform -->|owns| dbtobj & built
    transform -->|"MONITOR (TENDER_WH)"| base
    reporter -->|SELECT| marts
    cirole -->|SELECT| raw
    cirole -->|owns| cischemas
    viewer -->|"USAGE, REFERENCES"| structure
    viewer -->|MONITOR| tasks
    viewer -->|SELECT| guestdata
    viewer -->|USAGE| guestwh
```

- All four job roles (`TENDER_INGEST`, `TENDER_TRANSFORM`, `TENDER_REPORTER`, `TENDER_CI`) also have `USAGE` on `TENDER_WH`; left out to keep the picture readable.
- Pull requests are built as `TENDER_CI`, which can read `RAW` and create schemas, and owns only the `CI_PR_*` ones it creates; it can't touch `PROD_*` or `DEV_*`. The deploy key is a secret of the GitHub environment `production`, which only `main` can use, so pull request workflows never see it ([ADR 0033](../adr/0033-pipeline-safeguards.md)).
- `TENDER_VIEWER` is for guests: it browses everything, queries `RAW` and the prod schemas, and runs only on `TENDER_VIEWER_WH`, which a resource monitor caps at 1 credit a month. `PUBLIC`'s default warehouses and compute pools are revoked so they can't be used instead ([ADR 0029](../adr/0029-guest-role-with-capped-warehouse.md)). The guest's user name and password are passed in when the script runs, not committed.
- Grants live in `snowflake/setup/03–06`, `snowflake/native_ingestion/01_external_access.sql` and `snowflake/dbt/00_dbt_setup.sql`; `SELECT` on each mart table is re-granted by dbt on every build.
- The API integration lets the loader reach one host only (network rule `FIND_A_TENDER_API_RULE`).
- Snowflake activates a user's secondary roles too, so the Power BI user holds `TENDER_REPORTER` and nothing else.
- Buyer contact details stay in `RAW`; staging strips them, including from the stored JSON, and a dbt test enforces it ([ADR 0016](../adr/0016-strip-contact-details-in-staging.md)).
