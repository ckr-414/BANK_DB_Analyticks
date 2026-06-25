-- macros/audit_framework.sql
-- Called from on-run-start / on-run-end / post-hooks.
-- Creates audit tables + logs every model run.

{% macro create_audit_tables_if_not_exist() %}
  CREATE SCHEMA IF NOT EXISTS
    {{ var('target_database') }}.{{ var('audit_schema') }};

  CREATE TABLE IF NOT EXISTS
    {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_run_log (
      run_log_id       VARCHAR(36)   NOT NULL,
      dbt_run_id       VARCHAR(200)  NOT NULL,
      model_name       VARCHAR(200),
      layer            VARCHAR(50),
      run_started_at   TIMESTAMP_NTZ NOT NULL,
      run_completed_at TIMESTAMP_NTZ,
      duration_sec     FLOAT,
      rows_written     INTEGER,
      status           VARCHAR(20),
      error_message    VARCHAR(4000),
      dag_id           VARCHAR(200),
      job_name         VARCHAR(200),
      run_by           VARCHAR(200),
      env              VARCHAR(20),
      enter_dt         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      enter_by         VARCHAR(200)  DEFAULT CURRENT_USER(),
      update_dt        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      update_by        VARCHAR(200)  DEFAULT CURRENT_USER()
  );

  CREATE TABLE IF NOT EXISTS
    {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_row_count_log (
      snapshot_id      VARCHAR(36)   NOT NULL,
      model_name       VARCHAR(200)  NOT NULL,
      snapshot_date    DATE          NOT NULL,
      row_count        INTEGER       NOT NULL,
      prev_row_count   INTEGER,
      delta_rows       INTEGER,
      delta_pct        FLOAT,
      status           VARCHAR(20),
      dbt_run_id       VARCHAR(200),
      dag_id           VARCHAR(200),
      env              VARCHAR(20),
      enter_dt         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      enter_by         VARCHAR(200),
      update_dt        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      update_by        VARCHAR(200)
  );

  CREATE TABLE IF NOT EXISTS
    {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_test_log (
      test_log_id      VARCHAR(36)   NOT NULL,
      dbt_run_id       VARCHAR(200)  NOT NULL,
      test_name        VARCHAR(500)  NOT NULL,
      model_name       VARCHAR(200),
      column_name      VARCHAR(200),
      status           VARCHAR(20)   NOT NULL,
      failure_count    INTEGER,
      severity         VARCHAR(20),
      dag_id           VARCHAR(200),
      env              VARCHAR(20),
      enter_dt         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      enter_by         VARCHAR(200)  DEFAULT CURRENT_USER(),
      update_dt        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
      update_by        VARCHAR(200)  DEFAULT CURRENT_USER()
  )
{% endmacro %}


{% macro log_pipeline_start() %}
  INSERT INTO {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_run_log
    (run_log_id,dbt_run_id,model_name,status,run_started_at,
     dag_id,job_name,run_by,env,enter_dt,enter_by,update_dt,update_by)
    SELECT UUID_STRING(), '{{ invocation_id }}', 'PIPELINE_START', 'RUNNING',
    CURRENT_TIMESTAMP(),
    '{{ var("dag_id") }}',
    '{{ var("job_name") }}',
    '{{ var("run_by") }}',
    '{{ var("env") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}'
{% endmacro %}


{% macro log_pipeline_end() %}
  UPDATE {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_run_log
  SET status='SUCCESS', run_completed_at=CURRENT_TIMESTAMP(),
      update_dt=CURRENT_TIMESTAMP(),
      update_by='{{ var("job_name") }}'
  WHERE dbt_run_id='{{ invocation_id }}'
    AND model_name='PIPELINE_START'
{% endmacro %}


{% macro log_model_run(model) %}
  INSERT INTO {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_run_log
    (run_log_id,dbt_run_id,model_name,layer,
     run_started_at,run_completed_at,rows_written,status,
     dag_id,job_name,run_by,env,
     enter_dt,enter_by,update_dt,update_by)
  SELECT
    UUID_STRING(), '{{ invocation_id }}',
    '{{ model.name }}', '{{ model.path.split("/")[0] }}',
    CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(),
    (SELECT COUNT(*) FROM {{ model }}), 'SUCCESS',
    '{{ var("dag_id") }}',
    '{{ var("job_name") }}',
    '{{ var("run_by") }}',
    '{{ var("env") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}'
{% endmacro %}


{% macro audit_row_count_snapshot() %}
  INSERT INTO {{ var('target_database') }}.{{ var('audit_schema') }}.dbt_row_count_log
    (snapshot_id,model_name,snapshot_date,row_count,prev_row_count,
     delta_rows,delta_pct,status,dbt_run_id,dag_id,env,
     enter_dt,enter_by,update_dt,update_by)
  WITH curr AS (
    SELECT 'stg_customers'              AS m, COUNT(*) AS c
    FROM {{var('target_database')}}.{{var('staging_schema')}}.stg_customers
    UNION ALL SELECT 'stg_transactions', COUNT(*)
    FROM {{var('target_database')}}.{{var('staging_schema')}}.stg_transactions
    UNION ALL SELECT 'stg_loans', COUNT(*)
    FROM {{var('target_database')}}.{{var('staging_schema')}}.stg_loans
    UNION ALL SELECT 'int_customer_account_summary', COUNT(*)
    FROM {{var('target_database')}}.{{var('intermediate_schema')}}.int_customer_account_summary
    UNION ALL SELECT 'mart_customer_360', COUNT(*)
    FROM {{var('target_database')}}.{{var('marts_schema')}}.mart_customer_360
    UNION ALL SELECT 'mart_loan_portfolio_health', COUNT(*)
    FROM {{var('target_database')}}.{{var('marts_schema')}}.mart_loan_portfolio_health
  ),
  prev AS (
    SELECT model_name, row_count AS pc
    FROM {{var('target_database')}}.{{var('audit_schema')}}.dbt_row_count_log
    WHERE snapshot_date = DATEADD('day',-1,CURRENT_DATE)
  )
  SELECT
    UUID_STRING(), c.m, CURRENT_DATE, c.c, p.pc,
    c.c - COALESCE(p.pc,0),
    ROUND(100.0*(c.c-COALESCE(p.pc,0))/NULLIF(p.pc,0),2),
    CASE WHEN c.c=0 THEN 'EMPTY'
         WHEN c.c > COALESCE(p.pc,0)*1.5 THEN 'SPIKE'
         WHEN c.c < COALESCE(p.pc,0)*0.8 THEN 'DROP'
         ELSE 'NORMAL' END,
    '{{ invocation_id }}',
    '{{ var("dag_id") }}',
    '{{ var("env") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}',
    CURRENT_TIMESTAMP(),
    '{{ var("job_name") }}'
  FROM curr c LEFT JOIN prev p ON c.m = p.model_name
{% endmacro %}
