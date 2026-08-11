{{ config(
    materialized = 'table',
    schema = 'marts'
) }}

/*
  MODEL: dim_models
  PURPOSE: 
    1. Dimension table capturing AI model metadata and historical token pricing using SCD Type 2 tracking.
    2. Transforms snapshot fields into point-in-time time windows (dbt_valid_from to dbt_valid_to).
    3. Handles openS-ended current records using a far-future timestamp (2100-12-31) to simplify downstream Fact range joins.
*/

WITH snapshot_models AS (
    SELECT
        model_sk,
        id AS model_id,
        provider,
        is_active AS is_model_active,
        updated_at,
        prompt_price_per_1k,
        completion_price_per_1k,
        dbt_valid_from,
        
        -- 1. Derive current record boolean flag prior to replacing NULL valid_to timestamps
        (dbt_valid_to IS NULL) AS is_current,
        
        -- 2. Cap open-ended current records with a far-future upper bound to enable simple BETWEEN / range JOINs
        COALESCE(dbt_valid_to, CAST('2100-12-31 23:59:59' AS TIMESTAMP_NTZ)) AS dbt_valid_to
        
    FROM {{ ref('stg_models_snapshot') }}
)

SELECT
    model_sk,
    model_id,
    provider,
    is_model_active,
    updated_at,
    prompt_price_per_1k,
    completion_price_per_1k,
    dbt_valid_from,
    dbt_valid_to,
    is_current
FROM snapshot_models