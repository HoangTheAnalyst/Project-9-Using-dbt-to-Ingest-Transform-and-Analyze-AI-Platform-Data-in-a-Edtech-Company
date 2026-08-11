{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_conversations
  PURPOSE: 
    1. Clean and normalize chat conversation metadata ingested via Airbyte.
    2. Generate deterministic MD5 surrogate keys for conversations and associated users.
    3. Inject a static 'unknown_conversation' fallback record to preserve referential integrity across downstream joins.
*/

WITH raw_conversations AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_conversations') }}
),  

conversations AS (
    SELECT
        id,
        
        -- 1. Generate deterministic MD5 surrogate key for conversation primary key
        MD5(CAST(id AS STRING)) AS conversation_sk,
        
        -- 2. Generate MD5 surrogate key for user foreign key with fallback handling for missing user IDs
        COALESCE(MD5(CAST(user_id AS STRING)), MD5('unknown_user')) AS user_sk,
        
        -- 3. Cast and normalize timestamp fields to TIMESTAMP_NTZ
        CAST(COALESCE(created_at, _airbyte_extracted_at) AS TIMESTAMP_NTZ) AS created_at,
        CAST(_airbyte_extracted_at AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
        
    FROM raw_conversations
    WHERE
        -- 4. Filter out invalid records with missing conversation identifiers
        id IS NOT NULL
),

add_null_conversations AS (
    -- Retain cleaned conversation records
    SELECT
        id,
        conversation_sk,
        user_sk,
        created_at,
        _airbyte_extracted_at
    FROM conversations

    UNION ALL   

    -- Inject a static fallback record to handle missing or orphaned conversation keys in downstream models
    SELECT
        'unknown_conversation' AS id,
        MD5('unknown_conversation') AS conversation_sk,
        MD5('unknown_user') AS user_sk,
        CAST('1900-01-01T00:00:00' AS TIMESTAMP_NTZ) AS created_at,
        CAST('1900-01-01T00:00:01' AS TIMESTAMP_NTZ) AS _airbyte_extracted_at
)

SELECT 
    id,
    conversation_sk,
    user_sk,
    created_at,
    _airbyte_extracted_at
FROM add_null_conversations