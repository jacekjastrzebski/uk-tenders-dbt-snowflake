# 0025. Replace unusable organisation names

Status: Accepted (2026-10-08)

## Context
A few buyers and suppliers publish names that can't identify them. 34 different buyers published `[]`, which the marts group by name, so they appeared as one fake buyer. Other examples are `1`, `2`, `No`, `Test`, `[test]589b35c8B` and `Anglian Water (TEST)` for buyers (7 names on 187 of 172,375 notices), and amounts (`384441.61`, `91,200`), `.` and `N/A` for suppliers (21 of 76,361). Short names are not the problem: acronyms such as YPO, HS2, S4C and MOD are real buyer names. Names in other scripts (e.g. Chinese company names) are also real. Every notice has a buyer ID, and every award supplier has a supplier ID.

## Decision
- A name is unusable when it has only digits, punctuation and spaces, is a test entry ("test", or containing `[test]` or `(test)`), or is a placeholder (`No`, `N/A`, `NA`, `None`, `Unknown`, `TBC`): macro `is_unusable_org_name`.
- Staging (`stg_find_a_tender__notices`, `stg_find_a_tender__award_suppliers`) replaces an unusable name with the latest usable name published under the same organisation ID. If there is none, the name becomes "Unnamed buyer (ID)" or "Unnamed supplier (ID)", so different organisations are never merged.
- `dbt/tests/assert_org_names_usable.sql` checks that no buyer or supplier in the marts has an unusable name.
- Names that look like tender titles ("Riddlesdown Collegiate LED Lighting") are left alone: each still identifies one organisation, and spotting them would mean guessing.

## Consequences
- 33 of the 34 `[]` buyers join their real buyer rows; 3 buyers and 19 suppliers show as "Unnamed …"; headline totals don't change.
- The raw name stays in `RAW` for tracing.
- A new kind of junk name needs a change to the macro; the test only catches the kinds the macro knows.
