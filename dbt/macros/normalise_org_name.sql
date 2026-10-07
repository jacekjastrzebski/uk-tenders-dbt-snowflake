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
  Grouping key for organisation names: lot numbers removed, upper case, single
  spaces. The same organisation appears under several IDs (old Find a Tender,
  PPON, Companies House), so marts group buyers and suppliers by this instead.
  Use it everywhere an organisation is joined, so keys always match.
#}
{% macro normalise_org_name(column) -%}
    UPPER(TRIM(REGEXP_REPLACE({{ strip_lot_numbers(column) }}, '\\s+', ' ')))
{%- endmacro %}
