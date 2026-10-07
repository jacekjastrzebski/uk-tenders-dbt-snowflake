# 0007. Classify notices by noticeType, not tag

Status: Accepted (2026-10-07). Evidence: [eda-findings.md](../eda-findings.md).

## Context
Each notice has an OCDS `tag` (planning, tender, award, contract, ...) and, in its documents, a Procurement Act `noticeType` (UK1–UK17). In the data, `award,contract` covers UK5, UK6, UK7 and UK15 alike.

## Decision
Staging derives `notice_type` from `documents[].noticeType` and uses it to classify notices. `tags` is kept for spotting updates and cancellations.

## Consequences
- Marts can follow the Procurement Act lifecycle (UK4 tender → UK6 award → UK7 contract).
- Older-regime notices have no `noticeType` (`is_procurement_act = false`) and need separate handling.
