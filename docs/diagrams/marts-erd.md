# Marts entity-relationship diagram

The star schema the Power BI report reads ([ADR 0019](../adr/0019-star-schema-for-power-bi.md)). Grows as marts are built; key and defining columns only, details in `dbt docs`. Keep in step with the models (rule in `CLAUDE.md`).

```mermaid
erDiagram
    FCT_AWARD_SUPPLIERS }o--|| DIM_DATES : "award_date"
    FCT_AWARD_SUPPLIERS }o--|| DIM_BUYERS : "buyer_key"
    FCT_AWARD_SUPPLIERS }o--|| DIM_SUPPLIERS : "supplier_key"
    FCT_AWARD_SUPPLIERS }o--o| DIM_CPV_DIVISIONS : "cpv_division"
    FCT_PROCUREMENTS }o--|| DIM_DATES : "tender_published_date"
    FCT_PROCUREMENTS }o--o| DIM_BUYERS : "buyer_key"
    FCT_PROCUREMENTS }o--o| DIM_CPV_DIVISIONS : "cpv_division"

    FCT_PROCUREMENTS {
        string ocid PK "one Procurement Act tender"
        string buyer_key FK
        string cpv_division FK
        string title
        date tender_published_date FK "first UK4"
        date closing_date "latest UK4: bid or interest deadline"
        date award_published_date "first UK6, else UK7"
        date contract_published_date "first UK7"
        int days_tender_to_award
        int days_award_to_contract
        boolean is_cancelled "UK12 and no award"
    }

    FCT_AWARD_SUPPLIERS {
        string award_supplier_key PK "procurement_award_key/supplier_key"
        string procurement_award_key "ocid/award_id"
        date award_date FK "UK date"
        string buyer_key FK
        string supplier_key FK "or UNKNOWN SUPPLIER"
        string cpv_division FK "may be null"
        number allocated_value_gbp "equal share: sum this"
        string value_source "award or contract, net or gross"
        boolean is_framework "ceiling, shown separately"
        boolean is_large_value "100m or more"
        boolean is_in_headline "counts in headline totals"
    }
    DIM_DATES {
        date calendar_date PK "1990-01-01 to 2035-12-31"
        int calendar_year
        int month_number "sort key for month_name"
        string month_name
        date month_start "monthly trend axis"
        string year_month "e.g. 2026-10"
        date week_start "Monday"
        string financial_year "e.g. 2026/27"
        int financial_month_number "April = 1"
    }
    DIM_CPV_DIVISIONS {
        string cpv_division PK "e.g. 72; facts join on LEFT(cpv_code, 2)"
        string division_name "e.g. IT services"
        boolean is_digital_and_data "48 and 72"
        string market "Digital and data or Other"
    }
    DIM_BUYERS {
        string buyer_key PK "normalised name"
        string buyer_name "from the latest notice"
        string buyer_ids "all IDs seen, comma-separated"
    }
    DIM_SUPPLIERS {
        string supplier_key PK "normalised name, lots removed"
        string supplier_name "from the latest notice"
        string supplier_ids "all IDs seen, comma-separated"
        boolean is_withheld "name withheld (section 94)"
    }
```

## Reading notes

- `FCT_PROCUREMENTS`: one row per tender. Open = `closing_date` from today, no `award_published_date`, not `is_cancelled`, worked out in Power BI so it never goes stale. Its other dates also join `DIM_DATES`, as inactive relationships.
- `FCT_AWARD_SUPPLIERS`: one row per supplier on an award; sum `allocated_value_gbp`, filtered on `is_in_headline` for headline numbers. Rules in [ADR 0022](../adr/0022-award-fact-rules.md).
- Facts join buyers on `buyer_key` and suppliers on `supplier_key`: the name normalised with the macro `normalise_org_name` (lot numbers removed, upper case, single spaces), because one organisation appears under several IDs ([ADR 0021](../adr/0021-keep-supplier-names.md)).
- Facts join their CPV division (`LEFT(cpv_code, 2)`) to `cpv_division`; notices without a CPV code have no sector.
- Facts join their date columns (UK date, not UTC) to `calendar_date`; a fact has several dates, so in Power BI one relationship is active and the others are used with `USERELATIONSHIP`.
