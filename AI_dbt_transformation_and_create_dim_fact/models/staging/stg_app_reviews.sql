{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_app_reviews
  PURPOSE: 
    1. Clean, normalize, and validate application-level user review ratings ingested via Airbyte.
    2. Deduplicate review submissions per user_id to retain only the most recent rating per user.
    3. Generate MD5 user surrogate keys (user_sk) with fallback handling for missing user IDs.
*/

WITH raw_app_reviews AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_app_reviews') }}
),

app_reviews AS (
    SELECT
        -- 1. Partition by user_id to identify and retain only the latest review submission per user
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY 
                COALESCE(created_at, _airbyte_extracted_at) DESC,
                id DESC
        ) AS rn,
        
        -- 2. Generate MD5 surrogate key for user reference with fallback handling for missing user IDs
        COALESCE(MD5(CAST(user_id AS STRING)), MD5('unknown_user')) AS user_sk,
        
        -- 3. Default missing ratings to a neutral score (3) to prevent NULL values
        COALESCE(rating, 3) AS rating
        
    FROM raw_app_reviews
    WHERE 
        -- 4. Filter for valid 1-5 star ratings or NULL records (which are handled by COALESCE above)
        rating IN (1, 2, 3, 4, 5) OR rating IS NULL
)

SELECT 
    user_sk,
    rating AS latest_rating  
FROM app_reviews
WHERE rn = 1