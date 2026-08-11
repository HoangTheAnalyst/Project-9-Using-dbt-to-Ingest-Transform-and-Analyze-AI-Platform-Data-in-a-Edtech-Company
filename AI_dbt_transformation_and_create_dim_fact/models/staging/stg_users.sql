{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_users.sql
  PURPOSE: 
    1. Clean and standardize raw user data in raw_user_subscriptions ingested via Airbyte.
    2. Deduplicate records to retain only the latest user information per user.
    3. Append a default 'unknown_user' record to handle orphaned foreign keys during Mart-level joins.
*/

WITH raw_users AS (
    SELECT 
        *
    FROM {{ source('source_data', 'raw_user_subscriptions') }}
),

transformed_users AS (
    SELECT
        -- 1. Partition by user_id to order subscription history and identify the most recent record
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY 
                COALESCE(start_time, _airbyte_extracted_at) DESC,
                plan_id DESC
        ) AS rn,
        
        -- 2. Cast natural key and generate MD5 hash surrogate key
        CAST(user_id AS STRING) AS user_id,
        MD5(CAST(user_id AS STRING)) AS user_sk,
        
        -- 3. Handle missing plan attributes with a default fallback value
        COALESCE(plan_id, 'unknown_plan') AS plan_id,
        
        -- 4. Cast and normalize timestamp fields to TIMESTAMP_NTZ
        CAST(COALESCE(start_time, _airbyte_extracted_at) AS TIMESTAMP_NTZ) AS start_time,
        CAST(end_time AS TIMESTAMP_NTZ) AS end_time,
        CAST(_airbyte_extracted_at AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
        
    FROM raw_users
    WHERE
        -- 5. Filter out invalid records: missing user_id or illogical date ranges (end_time prior to start_time)
        user_id IS NOT NULL
        AND (
            end_time IS NULL 
            OR end_time >= COALESCE(start_time, _airbyte_extracted_at)
        )
),

adding_null_users AS (
    -- Retain only the latest subscription record per user
    SELECT 
        user_id,
        user_sk,
        plan_id,
        start_time,
        end_time,
        _airbyte_extracted_at
    FROM transformed_users
    WHERE rn = 1

    UNION ALL

    -- Inject a static fallback 'unknown_user' record to preserve referential integrity across downstream Fact joins
    SELECT 
        'unknown_user' AS user_id,
        MD5(CAST('unknown_user' AS STRING)) AS user_sk,
        'unknown_plan' AS plan_id,
        CAST('1900-01-01T00:00:00' AS TIMESTAMP_NTZ) AS start_time,
        CAST('9999-12-31T23:59:59' AS TIMESTAMP_NTZ) AS end_time,
        CAST('1900-01-01T00:00:01' AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
)

SELECT 
    user_id,
    user_sk,
    plan_id AS newest_plan_id,
    start_time AS start_of_newest_plan,
    end_time AS end_of_newest_plan,
    _airbyte_extracted_at
FROM adding_null_users