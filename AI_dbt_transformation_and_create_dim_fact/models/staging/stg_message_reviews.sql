{{ config(
    materialized = 'view',
    schema = 'staging'
) }}

/*
  MODEL: stg_message_reviews
  PURPOSE: 
    1. Clean and standardize user rating feedback and feedback categories for AI messages.
    2. Deduplicate review submissions per message_id to prevent fan-out when joining downstream Fact tables.
    3. Enforce strict data quality filters on accepted review categories and rating values.
*/

WITH raw_message_reviews AS (
    SELECT
        *
    FROM {{ source('source_data', 'raw_message_reviews') }}
), 

latest_message_reviews AS (
    SELECT
        -- 1. Partition by message_id to identify and retain only the most recent review submission
        ROW_NUMBER() OVER (
            PARTITION BY message_id
            ORDER BY 
                COALESCE(created_at, _airbyte_extracted_at) DESC,
                id DESC
        ) AS rn,
        
        id,
        message_id,
        rating,
        category AS review_category
        
    FROM raw_message_reviews
    WHERE 
        -- 2. Ensure valid foreign key reference
        message_id IS NOT NULL
        
        -- 3. Filter for recognized review categories
        AND category IN ('Speed', 'Relevance', 'Formatting', 'Accuracy')
        
        -- 4. Filter for recognized rating types
        AND rating IN ('like', 'dislike', '1_star', '5_star')
)

SELECT 
    id,
    message_id,
    rating,
    review_category
FROM latest_message_reviews
WHERE rn = 1