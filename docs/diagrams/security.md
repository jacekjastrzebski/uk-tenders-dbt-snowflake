# Security

Who can read or change what. Overview: [architecture.md](../architecture.md).

## Roles and access

Read left to right: users hold roles, roles have privileges on objects. Solid arrows are grants; dotted arrows mean a role inherits another (SYSADMIN can do whatever the three job roles can). One role per job, each with only what that job needs ([ADR 0004](../adr/0004-least-privilege-roles-and-deploy-user.md)).

```mermaid
flowchart LR
    subgraph Users
        you["You (person)"]
        deploy["TENDER_DEPLOY<br/>service user, key pair"]
        powerbi["TENDER_POWERBI<br/>service user, key pair"]
    end
    subgraph Roles
        sysadmin["SYSADMIN"]
        ingest["TENDER_INGEST<br/>loads"]
        transform["TENDER_TRANSFORM<br/>models"]
        reporter["TENDER_REPORTER<br/>reads marts"]
    end
    subgraph Objects["Objects"]
        base["TENDER_DB, TENDER_WH"]
        raw["RAW tables"]
        stage["CODE_STAGE"]
        rawobj["RAW procedures, task, alert"]
        integrations["FIND_A_TENDER_API_ACCESS,<br/>TENDER_EMAIL"]
        dbtobj["DBT schema:<br/>project, task, alert"]
        built["PROD_* and DEV_* schemas"]
        marts["PROD_MARTS, DEV_MARTS"]
    end

    you --> sysadmin & transform & reporter
    deploy --> ingest & transform
    powerbi --> reporter
    sysadmin -.-> ingest & transform & reporter

    sysadmin -->|owns| base & raw & stage
    ingest -->|"SELECT, INSERT"| raw
    ingest -->|"READ, WRITE"| stage
    ingest -->|owns| rawobj
    ingest -->|uses| integrations
    transform -->|SELECT| raw
    transform -->|owns| dbtobj & built
    reporter -->|SELECT| marts
```

- All three job roles also have `USAGE` on `TENDER_WH`; left out to keep the picture readable.
- Grants live in `snowflake/setup/03–04`, `snowflake/native_ingestion/01_external_access.sql` and `snowflake/dbt/00_dbt_setup.sql`; `SELECT` on each mart table is re-granted by dbt on every build.
- The API integration lets the loader reach one host only (network rule `FIND_A_TENDER_API_RULE`).
- Snowflake activates a user's secondary roles too, so the Power BI user holds `TENDER_REPORTER` and nothing else.
- Buyer contact details stay in `RAW`; staging strips them, including from the stored JSON, and a dbt test enforces it ([ADR 0016](../adr/0016-strip-contact-details-in-staging.md)).
