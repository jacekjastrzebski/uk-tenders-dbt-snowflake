# 0027. One name per buyer ID when the ID has only a few names

Status: Accepted (2026-10-08); ties between names go to the most recent one since [0034](0034-award-data-corrections.md)

## Context
Some buyers publish under names that no name rule can match: Newlon Housing Trust also appears as "2, 10, 18, 27, 34, 42 Queensland Road" and "Albion Works Replacement Project"; A2Dominion as "A2Dominion Housing Group Ltd (A2D)". The ID is the same. Of about 8,350 buyer IDs, 587 use 2–5 names; a sample showed nearly all are one organisation (spellings, abbreviations such as "ICB", addresses, project titles), about 1 in 12 two organisations. IDs with many names (up to 15) belong to purchasing bodies that publish for many buyers ([ADR 0026](0026-looser-organisation-key.md)).

## Decision
In `stg_find_a_tender__notices`, a buyer ID with 2 to `max_names_per_buyer_id` (5) different names gets its most-used name on every notice. IDs with more names keep each name.

## Consequences
- Buyers drop from 4,550 to 4,176; headline totals don't change.
- A small organisation that shares an ID with a bigger one is shown under the bigger one's name; such names usually have 1–2 notices.
- The threshold is a dbt var, so it can be tuned.
