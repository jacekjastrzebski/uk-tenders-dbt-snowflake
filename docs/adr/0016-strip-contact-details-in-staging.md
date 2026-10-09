# 0016. Strip contact details from staging, including the stored JSON

Status: Accepted (2026-10-07); amended by [0029](0029-guest-role-with-capped-warehouse.md): the guest role can read `RAW`, contact details included

## Context
A data review found that `stg_find_a_tender__notices.notice` (the full notice JSON, kept for the child models) still held every party's `contactPoint`: 945 emails, 163 names and 135 phone numbers across 403 notices. The docs said staging left contact details out; only the `parties` model did. A recursive search showed `parties[].contactPoint` is the only structured place for contact details.

## Decision
- Staging removes `contactPoint` from each party inside the stored `notice` JSON (`OBJECT_DELETE`), so no staging table or column holds structured contact details. Child models read the cleaned JSON.
- Singular test `dbt/tests/assert_no_contact_points.sql` fails the build if a `contactPoint` reaches staging.
- Free-text fields can still contain email addresses (seen in `tender.submissionMethodDetails`, milestone, tender and document descriptions, `description`). They are kept, because they carry business meaning, and are treated as possibly personal: not exposed in marts without review.

## Consequences
- `RAW` remains the only place with contact details; access to `RAW` should stay limited to the loader and dbt roles.
- The `notice` column is internal to staging and not used by marts.
- Removing emails from free text would need pattern-based masking; not done now.
