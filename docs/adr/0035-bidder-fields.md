# 0035. Bidder fields: tender value, notice link, SME and competition

Status: Accepted (2026-10-10)

## Context
A page-by-page review of the report found what bidders miss: how big an open tender is, a link to the notice, whether it suits small businesses, how many awards go to SMEs, and which "wins" had no competition (about 43% of headline awards). All of it is in the notices.

## Decision
- `fct_procurements`, from the latest tender notice (UK4):
  - `tender_value_gbp`: `tender.value.amountGross` (incl. VAT, which most tenders publish; net is missing on about 1 in 5), GBP only, null when zero.
  - `is_framework`: `tender.techniques.hasFrameworkAgreement`.
  - `is_suitable_for_sme`: any lot with `suitability.sme`.
  - `tender_notice_url`: `https://www.find-tender.service.gov.uk/Notice/<notice_id>`.
- `fct_award_suppliers`:
  - `competition` from `tender.procurementMethod` on the award's latest notice: `direct` (direct awards, below threshold without competition) is Direct award; `open`, `selective`, `limited` are Competed; otherwise Not stated.
  - `supplier_scale` from the supplier's `details.scale` on the award's latest notice that gives one: SME, Large, Not stated.

## Consequences
- Tender values must never be added up: frameworks are 15% of open tenders but about 80% of their value, and their values are spending caps. The report shows them per tender, marked.
- Gross values are not comparable with award values, which are mostly net.
- Award-under-framework call-offs count as Competed, though some are direct call-offs.
- Supplier size is self-declared.
