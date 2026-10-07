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
```

## Reading notes

- Facts join their date columns (UK date, not UTC) to `calendar_date`; a fact has several dates, so in Power BI one relationship is active and the others are used with `USERELATIONSHIP`.
