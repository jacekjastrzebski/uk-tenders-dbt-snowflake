{#
  Drops the schemas a CI build created, e.g. CI_PR_35_STAGING and CI_PR_35_MARTS
  (ADR 0030). Only prefixes starting with CI_ are accepted, so it can never drop
  DEV or PROD schemas.
  Usage: dbt run-operation drop_ci_schemas --args '{prefix: CI_PR_35}'
#}
{% macro drop_ci_schemas(prefix) %}
    {% if not prefix.upper().startswith('CI_') %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas only drops CI_ schemas, got: " ~ prefix) }}
    {% endif %}
    {% set schemas = run_query(
        "SELECT schema_name FROM " ~ target.database ~ ".INFORMATION_SCHEMA.SCHEMATA"
        ~ " WHERE schema_name LIKE '" ~ prefix.upper() ~ "%'"
    ).columns[0].values() %}
    {% for schema in schemas %}
        {% do run_query("DROP SCHEMA IF EXISTS " ~ target.database ~ "." ~ schema ~ " CASCADE") %}
        {{ log("dropped " ~ schema, info=True) }}
    {% endfor %}
{% endmacro %}
