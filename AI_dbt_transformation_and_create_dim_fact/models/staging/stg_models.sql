{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_models
  PURPOSE: 
    1. Clean and normalize AI model metadata and token pricing metrics ingested via Airbyte.
    2. Generate a deterministic MD5 surrogate key (model_sk) using model ID and timestamp to align with SCD Type 2 tracking.
    3. Inject a static 'unknown_model' fallback record to preserve referential integrity across downstream joins.
*/

WITH raw_models AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_models') }}
), 

models AS (
    SELECT
        id,
        
        -- 1. Generate deterministic surrogate key based on ID and update timestamp for SCD tracking
        MD5(CAST(id AS STRING) || ' - ' || CAST(COALESCE(updated_at, _airbyte_extracted_at) AS STRING)) AS model_sk,
        
        -- 2. Fallback provider to model ID if provider is missing
        COALESCE(provider, id) AS provider,
        
        -- 3. Default active flag to FALSE if unrecorded
        COALESCE(is_active, FALSE) AS is_active,
        
        -- 4. Cast and normalize timestamps to TIMESTAMP_NTZ
        CAST(COALESCE(updated_at, _airbyte_extracted_at) AS TIMESTAMP_NTZ) AS updated_at,
        
        -- 5. Default missing token prices to 0.0 to prevent NULL propagation in downstream cost calculations
        COALESCE(prompt_price_per_1k, 0.0) AS prompt_price_per_1k,
        COALESCE(completion_price_per_1k, 0.0) AS completion_price_per_1k,
        
        CAST(_airbyte_extracted_at AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
    FROM raw_models
),

add_null_models AS (
    -- Retain cleaned model records
    SELECT
        id,
        model_sk,
        provider,
        is_active,
        updated_at,
        prompt_price_per_1k,
        completion_price_per_1k,
        _airbyte_extracted_at
    FROM models

    UNION ALL   

    -- Inject a static fallback record for unknown/unmatched models during downstream Fact table joins
    SELECT
        'unknown_model' AS id,
        MD5('unknown_model') AS model_sk,
        'unknown_provider' AS provider,
        FALSE AS is_active,
        CAST('1900-01-01T00:00:00' AS TIMESTAMP_NTZ) AS updated_at,
        CAST(0.0 AS NUMERIC(10, 5)) AS prompt_price_per_1k,
        CAST(0.0 AS NUMERIC(10, 5)) AS completion_price_per_1k,
        CAST('1900-01-01T00:00:01' AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
)

SELECT 
    id,
    model_sk,
    provider,
    is_active,
    updated_at,
    prompt_price_per_1k,
    completion_price_per_1k,
    _airbyte_extracted_at
FROM add_null_models