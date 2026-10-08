# 0021. Keep supplier names, group lots, flag withheld suppliers

Status: Accepted (2026-10-07); lot rule narrowed to two or more trailing tokens by [0034](0034-award-data-corrections.md)

## Context
`dim_suppliers` shows who wins public contracts. A check of supplier names without a company word (Ltd, PLC, LLP, …) found 66 of 626; nearly all are organisations (GP practices, charities, firms without a suffix), and only 2–3 may be sole traders' trading names, used in a business role. Find a Tender publishes them as open data. Names also carry framework lot numbers ("Pinsent Masons 1 2 3 4 5 6 7 8", "Kajima Partnerships a 1 8 b 1 8 h 8", "- Lot 1"), which split one supplier into several. Buyers can withhold a supplier's name under section 94 of the Procurement Act ("Withheld Section94 supplier").

## Decision
- Keep supplier names in the marts, including possible sole traders' trading names; contact details stay out (ADR 0016).
- Remove trailing lot numbers before grouping (macro `strip_lot_numbers`, used by `normalise_org_name` for buyers and suppliers).
- Flag withheld suppliers (`is_withheld`) so supplier rankings can leave them out; their awards still count in buyer totals.

## Consequences
- Supplier totals are not split across lots.
- The lot rule removes any trailing run of single letters and 1–2 digit numbers: a real name ending like that would be shortened; none found in the data (all 50 changed names checked).
- Revisit if a sole trader asks to be removed, or if names of individuals become common.
