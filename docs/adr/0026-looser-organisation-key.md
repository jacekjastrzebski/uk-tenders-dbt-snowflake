# 0026. Looser organisation key, and markets for the Market filter

Status: Accepted (2026-10-08)

## Context
Buyers and suppliers are grouped by a key built from their name ([ADR 0021](0021-keep-supplier-names.md)), because one organisation publishes under several IDs. The key was the name in upper case with single spaces, so spellings of one organisation stayed apart: "A2 Dominion Group" and "A2Dominion Group", "UK Biobank Limited" and "UK Biobank Ltd", "The London Borough of Harrow" and "London Borough of Harrow", "Foreign, Commonwealth and Development Office (FCDO)". Grouping by shared ID instead is wrong: some IDs belong to purchasing bodies that publish for many buyers (one covers Birmingham, Bristol and York councils).

The award rules count an award with 3 or more distinct suppliers as a framework ([ADR 0022](0022-award-fact-rules.md)), so one supplier written three ways ("Kellogg Brown & Root Ltd (KBR)", "Kellogg, Brown & Root Ltd", "… Limited") wrongly turned an award into a framework.

The Market filter had two values, Digital and data and Other; "Other" was 94% of the value.

## Decision
- `normalise_org_name` also removes a trailing "(…)", a leading "The", a trailing Limited / Ltd / PLC / LLP / CIC, and all spaces and punctuation. Only punctuation and spaces are removed, so names in other scripts keep their letters; a name that would end up empty keeps its plain upper-case form.
- Displayed buyer names are trimmed.
- The `cpv_divisions` seed gets a `market` column grouping the 45 divisions into 9 markets (Digital and data stays 48 and 72), plus Unknown for notices without a CPV code. The seed is rebuilt on every run (`full_refresh`), so new columns reach prod without a manual step.

## Consequences
- About 590 of 5,140 buyer rows and 13,100 of 76,400 supplier rows merge; supplier rankings and the top-10 share use whole organisations.
- 12 awards (£25m) that only looked like frameworks because of duplicate spellings now count in the headline (Oct 2025 – Sep 2026: 55,394 awards).
- A trailing bracket is dropped even when it names a team ("NHS England North West (Greater Manchester)" joins NHS England North West); acceptable for a market view.
- Keys are no longer readable names (A2DOMINIONGROUP); they are hidden in the report, which shows the latest published name.
