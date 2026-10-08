# Data

What one row means at each layer, and which dbt model reads which. Arrows follow the data, from source to mart. Table-level detail: [staging ERD](staging-erd.md), [marts ERD](marts-erd.md). Overview: [architecture.md](../architecture.md).

## Layers and grain

Each box is a table or view with its grain: what one row is. Staging keeps one row per notice, so the same award appears in several notices; `int_awards` deduplicates once, before anything is summed ([ADR 0015](../adr/0015-staging-as-tables.md), [ADR 0012](../adr/0012-business-terms-in-staging.md)).

```mermaid
flowchart TB
    API["Find a Tender API<br/>OCDS release packages"]
    subgraph RAW["RAW: tables, loaded by the procedure"]
        R1["FIND_A_TENDER_RELEASES<br/>1 row = 1 API page (≤ 100 notices)"]
        R2["FIND_A_TENDER_INGEST_RUNS<br/>1 row = 1 loader run"]
    end
    subgraph STG["PROD_STAGING: tables"]
        S1["notices<br/>1 row = 1 notice, latest copy"]
        S2["parties<br/>1 per organisation in a notice"]
        S3["awards<br/>1 per award in a notice"]
        S4["award_suppliers<br/>1 per supplier on an award"]
        S5["contracts<br/>1 per contract in a notice"]
        SH["seed: hmrc_exchange_rates<br/>1 per currency and month"]
        SC["seed: cpv_divisions<br/>1 per CPV division"]
    end
    subgraph INT["PROD_INTERMEDIATE: views"]
        I1["int_awards<br/>1 row = 1 award across all its notices, in GBP"]
    end
    subgraph MARTS["PROD_MARTS: tables, star schema"]
        F1["fct_procurements<br/>1 row = 1 Procurement Act tender"]
        F2["fct_award_suppliers<br/>1 row = 1 supplier on an award"]
        DIM["dim_buyers · dim_suppliers ·<br/>dim_cpv_divisions · dim_dates ·<br/>dim_data_freshness"]
    end
    API --> R1
    R1 --> S1 --> S2 & S3 & S4 & S5
    S1 & S3 & S4 & S5 & SH --> I1
    S1 --> F1
    I1 & S3 & S4 --> F2
    S1 & S4 & SC --> DIM
```

`FIND_A_TENDER_INGEST_RUNS` feeds the loader's watermark and dbt's freshness check, not the models. `parties` is not read by any mart yet. `dim_dates` is generated from project variables.

## dbt lineage

Every model, seed and source, as `dbt docs` draws it; tests are left out. Colours: blue cylinders are sources, green boxes seeds, white boxes staging and intermediate models, red boxes marts.

```mermaid
flowchart LR
    classDef source fill:#dde4ff,stroke:#5566aa
    classDef seed fill:#ddf4dd,stroke:#559955
    classDef mart fill:#ffe0e0,stroke:#aa5555

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
    dim_fresh["dim_data_freshness"]:::mart

    raw_rel --> notices
    notices --> parties & awards & award_sup & contracts
    notices & awards & award_sup & contracts & hmrc --> int_awards
    notices --> fct_proc
    int_awards & awards & award_sup --> fct_aws
    notices --> dim_buyers
    notices & award_sup --> dim_sup
    cpv --> dim_cpv
    notices --> dim_fresh
```

`raw.find_a_tender_ingest_runs` is declared for freshness only; no model reads it. `dim_dates` has no inputs.
