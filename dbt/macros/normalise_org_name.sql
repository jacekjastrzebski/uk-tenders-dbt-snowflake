{#
  Organisation names as published can carry framework lots at the end:
  "Pinsent Masons 1 2 3 4 5 6 7 8", "Kajima Partnerships a 1 8 b 1 8 h 8",
  "Liberate UK Limited - Lot 1". strip_lot_numbers removes a trailing
  "- Lot ..." or a trailing run of single letters and 1-2 digit numbers,
  so a supplier on several lots stays one supplier.
#}
{% macro strip_lot_numbers(column) -%}
    REGEXP_REPLACE(TRIM({{ column }}), '(\\s*-\\s*[Ll][Oo][Tt]\\s.*|(\\s+([A-Za-z]|[0-9]{1,2}))+)$', '')
{%- endmacro %}

{#
  Grouping key for organisation names. The same organisation appears under
  several IDs (old Find a Tender, PPON, Companies House) and several spellings,
  so marts group buyers and suppliers by this key instead
  (docs/adr/0026-looser-organisation-key.md). From the name it removes:
  lot numbers, a trailing "(...)" such as "(FCDO)", a leading "The", a trailing
  Limited / Ltd / PLC / LLP / CIC, then all spaces and punctuation, in upper case.
  "A2 Dominion Group" and "A2Dominion Group" both become A2DOMINIONGROUP.
  A name that would end up empty keeps its plain upper-case form.
  Use it everywhere an organisation is joined, so keys always match.
#}
{% macro normalise_org_name(column) -%}
    COALESCE(
        NULLIF(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(UPPER({{ strip_lot_numbers(column) }}), '\\s*\\([^)]*\\)$', ''),
                        '^THE\\s+', ''),
                    '\\s+(LIMITED|LTD\\.?|PLC|LLP|CIC)$', ''),
                '[[:punct:][:space:]]', ''),
            ''),
        UPPER(TRIM({{ column }}))
    )
{%- endmacro %}

{#
  Names that can't identify an organisation: only digits, punctuation and
  spaces ("[]", "1", "384441.61"), test entries ("Test", "[test]589b35c8B",
  "Anglian Water (TEST)") and placeholders ("No", "N/A"). Acronyms such as
  "YPO" or "HS2" are real names and stay. Staging replaces these names with
  the same organisation's name from its other notices (ADR 0025).
#}
{% macro is_unusable_org_name(column) -%}
    (
        REGEXP_LIKE({{ column }}, '[0-9[:punct:][:space:]£€$]*')
        OR REGEXP_LIKE(TRIM({{ column }}), 'test|.*(\\[|\\()test(\\]|\\)).*', 'i')
        OR UPPER(TRIM({{ column }})) IN ('NO', 'N/A', 'NA', 'NONE', 'UNKNOWN', 'TBC')
    )
{%- endmacro %}
