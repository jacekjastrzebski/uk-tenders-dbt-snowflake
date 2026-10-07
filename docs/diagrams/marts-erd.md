# Marts entity-relationship diagram

The star schema the Power BI report reads ([ADR 0019](../adr/0019-star-schema-for-power-bi.md)). Grows as marts are built; key and defining columns only, details in `dbt docs`. Keep in step with the models (rule in `CLAUDE.md`).

```mermaid
erDiagram
    DIM_DATES {
        date calendar_date PK "2015-01-01 to 2035-12-31"
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

- Facts join buyers on `buyer_key` and suppliers on `supplier_key`: the name normalised with the macro `normalise_org_name` (lot numbers removed, upper case, single spaces), because one organisation appears under several IDs ([ADR 0021](../adr/0021-keep-supplier-names.md)).
- Facts join their CPV division (`LEFT(cpv_code, 2)`) to `cpv_division`; notices without a CPV code have no sector.
- Facts join their date columns (UK date, not UTC) to `calendar_date`; a fact has several dates, so in Power BI one relationship is active and the others are used with `USERELATIONSHIP`.
