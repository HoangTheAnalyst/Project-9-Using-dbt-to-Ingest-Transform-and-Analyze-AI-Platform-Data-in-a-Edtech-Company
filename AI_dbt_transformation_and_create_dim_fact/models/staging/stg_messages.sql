{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_messages
  PURPOSE: 
    1. Clean, validate, and normalize AI interaction message logs ingested via Airbyte.
    2. Derive boolean feature flags indicating input modalities (text vs. file) and output responses.
    3. Enforce strict data quality filters on token metrics and error/response state consistency.
*/

WITH raw_messages AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_messages') }}
),

messages AS (
    SELECT
        id,
        
        -- 1. Generate MD5 surrogate key for conversation with fallback for orphaned records
        COALESCE(MD5(CAST(conversation_id AS STRING)), MD5('unknown_conversation')) AS conversation_sk,
        
        -- 2. Fallback missing model identifiers
        COALESCE(CAST(model_id AS STRING), 'unknown_model') AS model_id,
        
        prompt_tokens,
        completion_tokens,
        is_error,
        
        -- 3. Derive boolean flags for user input payload types
        (user_prompt IS NOT NULL) AS is_user_prompt,
        (user_file_url IS NOT NULL) AS is_user_uploaded_file,
        
        -- 4. Derive boolean flags for model response output modalities
        (model_answer_file_url IS NOT NULL) AS is_model_answer_file,
        (model_answer_text IS NOT NULL) AS is_model_answer_text,
        
        -- 5. Cast and normalize timestamp fields to TIMESTAMP_NTZ
        CAST(COALESCE(created_at, _airbyte_extracted_at) AS TIMESTAMP_NTZ) AS created_at,
        CAST(_airbyte_extracted_at AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
        
    FROM raw_messages
    WHERE 
        -- 6. Enforce Primary Key and non-null error flag integrity
        id IS NOT NULL
        AND is_error IS NOT NULL
        
        -- 7. Validate token bounds (prompt tokens must be > 0; completion tokens must be >= 0)
        AND prompt_tokens > 0 
        AND prompt_tokens IS NOT NULL
        AND completion_tokens >= 0 
        AND completion_tokens IS NOT NULL
        
        -- 8. Enforce business state consistency: successful messages must contain content, 
        --    while error messages must not contain answer content
        AND (
            (is_error = FALSE AND (model_answer_text IS NOT NULL OR model_answer_file_url IS NOT NULL)) 
            OR 
            (is_error = TRUE AND model_answer_text IS NULL AND model_answer_file_url IS NULL)
        )
)

SELECT 
    id,
    conversation_sk,
    model_id,
    prompt_tokens,
    completion_tokens,
    is_error,
    is_user_prompt,
    is_user_uploaded_file,
    is_model_answer_file,
    is_model_answer_text,
    created_at,
    _airbyte_extracted_at
FROM messages