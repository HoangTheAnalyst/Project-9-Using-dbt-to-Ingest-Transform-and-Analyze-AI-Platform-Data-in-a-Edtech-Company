{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_plans
  PURPOSE: 
    1. Extract and standardize subscription plan master data from raw source tables.
    2. Enforce data quality by filtering for recognized, valid plan types.
    3. Inject a default 'unknown_plan' fallback record to ensure referential integrity during downstream joins.
*/

WITH raw_plans AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_plans') }}
),

plans AS (
    SELECT
        id,
        plan_type
    FROM raw_plans
    WHERE 
        -- Filter out invalid/unsupported plan types and exclude NULL records
        plan_type IN ('Free', 'Basic', 'Ultra') 
        AND plan_type IS NOT NULL
),

add_null_plans AS (
    -- Retain validated subscription plans
    SELECT
        id,
        plan_type
    FROM plans

    UNION ALL

    -- Inject a static fallback record to handle missing or orphaned plan keys in downstream models
    SELECT
        'unknown_plan' AS id,
        'unknown_plan_type' AS plan_type
)

SELECT 
    id,
    plan_type
FROM add_null_plans