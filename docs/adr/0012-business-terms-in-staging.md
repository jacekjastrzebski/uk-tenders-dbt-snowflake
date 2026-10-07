# 0012. Name models in business terms: notices, not releases

Status: Accepted (2026-10-07). Terms: [glossary.md](../glossary.md).

## Context
The API and OCDS call each published item a **release**; Find a Tender and the Procurement Act call it a **notice** (UK1–UK17, ID like `094475-2026`). In this data one release is exactly one notice: the release `id` is the notice ID.

## Decision
- Raw objects keep the source's terms: `RAW.FIND_A_TENDER_RELEASES`, `payload:releases`.
- From staging on, models and columns use business terms: `stg_find_a_tender__notices`, `notice_id`, `notice_type`.
- Staging is where the switch happens; terms are defined in `docs/glossary.md`.

## Consequences
- Dashboards, marts and docs speak the language of procurement users.
- Anyone reading raw SQL must know that one release = one notice; the glossary and model descriptions say so.
