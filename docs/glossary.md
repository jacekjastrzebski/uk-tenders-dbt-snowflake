# Glossary

Terms used in this project, grouped by area. Procurement background: [procurement-primer.md](procurement-primer.md).

## Procurement

| Term | Meaning |
|---|---|
| Notice | One publication on Find a Tender, e.g. a tender or a contract award; ID like `094475-2026`. Called a *release* in OCDS |
| Notice type | Procurement Act notice code UK1–UK17 (e.g. UK4 tender, UK6 contract award, UK7 contract details); found in `documents[].noticeType` |
| Procurement | One buying process from plan to contract end; all its notices share one `ocid` |
| Buyer | The public body buying (also: contracting authority) |
| Supplier | The organisation bidding for or delivering a contract |
| Award | The decision to give a contract to one or more suppliers |
| Contract | The signed agreement following an award |
| Lot | A separately awarded part of a procurement |
| CPV code | Common Procurement Vocabulary: standard code for what is bought |
| Old-regime notice | A notice under the rules before the Procurement Act 2023 (24 Feb 2025); has no notice type |

## OCDS and the API

| Term | Meaning |
|---|---|
| OCDS | Open Contracting Data Standard: the JSON format Find a Tender publishes in |
| Release | One OCDS JSON object; in this data, exactly one notice |
| Release package | One API response: wrapper metadata plus up to 100 releases in `releases` |
| Page | One release package as stored in `RAW.FIND_A_TENDER_RELEASES` (one row per page) |
| `ocid` | Procurement ID, shared by all notices of one procurement |
| Tag | OCDS release tag (planning, tender, award, contract, `*Update`, ...); too coarse to classify notices, see [ADR 0007](adr/0007-classify-notices-by-notice-type.md) |
| Party | An organisation named in a notice, with roles (buyer, supplier, ...) |
| Cursor | Token in `links.next` that fetches the next page |

## Ingestion

| Term | Meaning |
|---|---|
| Load / run | One execution of the loader; logged in `RAW.FIND_A_TENDER_INGEST_RUNS` |
| Window | The time range a run fetches: notices updated between `updatedFrom` and `updatedTo` |
| Watermark | End of the last successful run's window; the next window starts here |
| Overlap | Each window starts 15 minutes before the watermark, see [ADR 0011](adr/0011-load-window-overlap.md) |
| Duplicate | A notice loaded by more than one run; removed in staging (latest load wins) |

## Snowflake

| Term | Meaning |
|---|---|
| Warehouse | Compute that runs queries; billed per second while running (`TENDER_WH`) |
| Serverless | Compute Snowflake sizes and manages itself, billed per use (the ingest task, the alert) |
| Stage | File storage inside Snowflake; `CODE_STAGE` holds the loader file |
| Stored procedure | Code stored and run in Snowflake; `LOAD_FIND_A_TENDER_RELEASES` runs the Python loader |
| Task | A scheduled statement; `INGEST_FIND_A_TENDER` calls the procedure |
| Alert | A scheduled check that runs an action when its condition is true; emails on failed loads |
| Stream | Tracks new rows in a table; not used yet (option for triggered tasks) |
| Role | A set of privileges; one per job: `TENDER_INGEST`, `TENDER_TRANSFORM` |
| Service user | A user for automation, key-pair login only: `TENDER_DEPLOY` |
| Integration | Account-level connection to something outside: API access, email |

## dbt

| Term | Meaning |
|---|---|
| Model | A `SELECT` in a `.sql` file that dbt builds as a view or table |
| Source | Raw data declared in YAML and referenced with `source()` |
| Staging | First layer: one cleaned, deduplicated model per entity; business names |
| Mart | Dashboard-ready tables (facts and dimensions); next step |
| Materialisation | How a model is built: view, table, incremental |
| Test | A query that must return no rows (e.g. `unique`, `not_null`) |
| Freshness | Check that a source's newest `loaded_at` is recent enough |
| Target | A named connection in `profiles.yml` (`dev`, `prod`); decides which schemas dbt writes to |
| Profile | Connection settings in `~/.dbt/profiles.yml`, outside the repo |
| Macro | Reusable Jinja code, e.g. `generate_schema_name` |
