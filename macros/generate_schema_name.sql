-- macros/generate_schema_name.sql
-- ┌──────────────────────────────────────────────────────────┐
-- │  WITHOUT this macro dbt builds:  dbt_banking_MARTS  (WRONG) │
-- │  WITH    this macro dbt builds:  MARTS          (RIGHT)  │
-- │  Returns schema = EXACTLY the value passed via var().    │
-- └──────────────────────────────────────────────────────────┘
{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- if custom_schema_name is none -%}
    {{ target.schema }}
  {%- else -%}
    {{ custom_schema_name | trim }}
  {%- endif -%}
{%- endmacro %}
 
-- ── How it connects: ─────────────────────────────────────────
-- dbt_project.yml:    +schema: "{{ var('marts_schema') }}"
-- profiles.yml:       vars: { marts_schema: MARTS }
-- env var:            DBT_MARTS_SCHEMA=MARTS
-- this macro returns: "MARTS"
-- final table lands:  BANK_DB.MARTS.mart_customer_360  ✓