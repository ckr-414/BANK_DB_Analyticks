-- macros/audit_columns.sql
-- All values come from dbt vars (which are sourced from the
-- dbt Cloud Environment Variables tab in dbt_project.yml).
-- Reference var() here, never env_var() directly.

{% macro audit_columns(enter_from=none, enter_by_from=none) %}

  {% if enter_from %}
  {{ enter_from }}                AS enter_dt,
  {% else %}
  CURRENT_TIMESTAMP()             AS enter_dt,
  {% endif %}

  {% if enter_by_from %}
  {{ enter_by_from }}             AS enter_by,
  {% else %}
  '{{ var("job_name") }}'         AS enter_by,
  {% endif %}

  CURRENT_TIMESTAMP()             AS update_dt,
  '{{ var("job_name") }}'         AS update_by,
  '{{ var("dag_id") }}'           AS dag_id,
  CURRENT_TIMESTAMP()             AS dbt_loaded_at,
  '{{ invocation_id }}'           AS dbt_run_id,
  '{{ var("env") }}'              AS dbt_environment

{% endmacro %}


{% macro get_merge_update_cols() %}
  {%- set excluded = ['enter_dt','enter_by'] -%}
  {%- set cols = adapter.get_columns_in_relation(this) -%}
  {%- set result = [] -%}
  {%- for c in cols -%}
    {%- if c.name|lower not in excluded -%}{%- do result.append(c.name) -%}{%- endif -%}
  {%- endfor -%}
  {{ return(result) }}
{% endmacro %}


{% macro incremental_watermark(col, lookback_days=0) %}
  {%- if is_incremental() -%}
  WHERE {{ col }} >= (
    SELECT DATEADD('day', -{{ lookback_days }}, MAX({{ col }}))
    FROM {{ this }}
  )
  {%- endif -%}
{% endmacro %}
