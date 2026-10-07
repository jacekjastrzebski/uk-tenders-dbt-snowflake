{#
  Grouping key for organisation names: upper case, single spaces, trimmed.
  The same organisation appears under several IDs (old Find a Tender, PPON,
  Companies House), so marts group buyers and suppliers by this instead.
  Use it everywhere an organisation is joined, so keys always match.
#}
{% macro normalise_org_name(column) -%}
    UPPER(TRIM(REGEXP_REPLACE({{ column }}, '\\s+', ' ')))
{%- endmacro %}
