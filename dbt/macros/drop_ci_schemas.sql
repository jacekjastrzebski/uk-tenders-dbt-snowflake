{#
  Drops the schemas a CI build created, e.g. CI_PR_35_STAGING and CI_PR_35_MARTS
  (ADR 0030). Only prefixes like CI_PR_35 (CI_, then letters, digits and underscores)
  are accepted, so it can never drop DEV or PROD schemas. A schema matches when its
  whole name is the prefix plus at most one _SUFFIX, so CI_PR_3 never drops CI_PR_35_*.
  Usage: dbt run-operation drop_ci_schemas --args '{prefix: CI_PR_35}'
#}
{% macro drop_ci_schemas(prefix) %}
    {% set prefix = prefix | string | upper %}
    {% if not modules.re.fullmatch('CI_[A-Z0-9_]+', prefix) %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only drops CI_ schemas, got: " ~ prefix) }}
    {% endif %}
    {# REGEXP_LIKE matches the whole name, as if the pattern began with ^ and ended with $ #}
    {% set schemas = run_query(
        "SELECT schema_name FROM " ~ target.database ~ ".INFORMATION_SCHEMA.SCHEMATA"
        ~ " WHERE REGEXP_LIKE(schema_name, '" ~ prefix ~ "(_[A-Z]+)?')"
    ).columns[0].values() %}
    {% for schema in schemas %}
        {% do run_query("DROP SCHEMA IF EXISTS " ~ target.database ~ "." ~ schema ~ " CASCADE") %}
        {{ log("dropped " ~ schema, info=True) }}
    {% endfor %}
{% endmacro %}
