# Staging entity-relationship diagram

Raw tables and the dbt staging models: what one row is, the keys, and how tables relate. Key and defining columns only; every column with its description is in `dbt docs` ([dbt.md](../dbt.md)). Keep this diagram in step with the models (rule in `CLAUDE.md`).

```mermaid
erDiagram
    RAW_FIND_A_TENDER_INGEST_RUNS ||--o{ RAW_FIND_A_TENDER_RELEASES : "loads pages (run_id)"
    RAW_FIND_A_TENDER_RELEASES }o--o{ STG_NOTICES : "flattened; latest copy kept"
    STG_NOTICES ||--o{ STG_PARTIES : "names (notice_id)"
    STG_NOTICES ||--o{ STG_AWARDS : "contains (notice_id)"
    STG_NOTICES ||--o{ STG_CONTRACTS : "contains (notice_id)"
    STG_AWARDS ||--o{ STG_AWARD_SUPPLIERS : "won by (award_key)"
    STG_AWARDS ||--o{ STG_CONTRACTS : "signed as (notice_id, award_id)"
    STG_PARTIES ||..o{ STG_AWARD_SUPPLIERS : "supplier is a party (logical)"

    RAW_FIND_A_TENDER_INGEST_RUNS {
        string run_id PK "e.g. 20261007T104806Z"
        timestamp window_from
        timestamp window_to
        string status "success or failed"
        timestamp finished_at
    }
    RAW_FIND_A_TENDER_RELEASES {
        string run_id FK
        int page_number
        variant payload "API page: up to 100 releases"
        timestamp loaded_at
    }
    STG_NOTICES {
        string notice_id PK "e.g. 094475-2026"
        string ocid "procurement"
        string notice_type "UK1-UK17"
        timestamp published_at
        string buyer_id
        string cpv_code
        number tender_value_amount
        variant notice "full JSON"
    }
    STG_PARTIES {
        string party_key PK "notice_id/party_id"
        string notice_id FK
        string party_id
        string party_name
        array roles "buyer, supplier, ..."
    }
    STG_AWARDS {
        string award_key PK "notice_id/award_id"
        string notice_id FK
        string award_id
        timestamp awarded_at
        number award_value_amount
    }
    STG_AWARD_SUPPLIERS {
        string award_supplier_key PK "notice_id/award_id/supplier_id"
        string award_key FK
        string supplier_id "= party_id"
        string supplier_name
    }
    STG_CONTRACTS {
        string contract_key PK "notice_id/contract_id"
        string notice_id FK
        string award_id FK "award in the same notice"
        timestamp signed_at
        number contract_value_amount
    }
```

## Reading notes

| Table | One row is |
|---|---|
| `RAW_FIND_A_TENDER_INGEST_RUNS` | a loader run |
| `RAW_FIND_A_TENDER_RELEASES` | an API page (up to 100 releases) |
| `STG_NOTICES` | a notice (= one OCDS release), deduplicated across pages |
| `STG_PARTIES` | an organisation named in a notice |
| `STG_AWARDS` | an award in a notice |
| `STG_AWARD_SUPPLIERS` | a supplier on an award |
| `STG_CONTRACTS` | a contract in a notice |

- Staging tables are named `stg_find_a_tender__<entity>`; the `STG_` names above are shortened.
- **The same award or contract appears in several notices** of one procurement (`ocid`), e.g. a UK6 award and the later UK7 contract details. Staging keeps one row per notice; marts must deduplicate before summing values.
- `STG_PARTIES` to `STG_AWARD_SUPPLIERS` is a logical link (`supplier_id` = `party_id` in the same notice), not enforced by a test.
