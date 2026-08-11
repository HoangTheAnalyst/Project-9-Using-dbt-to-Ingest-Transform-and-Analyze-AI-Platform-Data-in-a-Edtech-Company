{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'message_id',
    schema = 'marts',
    on_schema_change = 'sync_all_columns'
) }}

/*
  MODEL: fct_messages
  PURPOSE: 
    1. Fact table capturing granular AI interaction logs, token usage metrics, and calculated API costs.
    2. Joins message events with user conversations and SCD Type 2 model pricing dimensions.
    3. Implements incremental loading with a 3-day lookback window to capture late-arriving message reviews.
*/

WITH dim_models AS (
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
    FROM {{ ref('dim_models') }}
),

stg_messages AS (
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
        created_at
    FROM {{ ref('stg_messages') }}
    
    {% if is_incremental() %}
        -- Lookback 3 days to capture late-arriving message review submissions
        WHERE created_at >= (SELECT DATEADD(day, -3, MAX(created_at)) FROM {{ this }})
    {% endif %}
),

stg_conversations AS (
    SELECT
        id,
        conversation_sk,
        user_sk,
        created_at
    FROM {{ ref('stg_conversations') }}
),

stg_message_reviews AS (
    SELECT
        id,
        message_id,
        rating,
        review_category
    FROM {{ ref('stg_message_reviews') }}
),

dim_messages AS (
    SELECT
        messages.id AS message_id,
        TO_NUMBER(TO_CHAR(messages.created_at, 'YYYYMMDD')) AS date_key,
        messages.conversation_sk,
        conversations.user_sk,
        
        /* 
          DEV NOTE / TRADE-OFF:
          A local `--full-refresh` on `stg_models_snapshot` wiped out historical valid_from/valid_to time windows.
          `COALESCE` is applied to assign default 'unknown_model' fallback values to preserve historical fact completeness.
        */
        COALESCE(models.model_id, 'unknown_model') AS model_id,
        COALESCE(models.model_sk, MD5('unknown_model')) AS model_sk,
        
        messages.is_error,
        messages.is_user_prompt,
        messages.is_user_uploaded_file,
        messages.is_model_answer_file,
        messages.is_model_answer_text,
        messages.prompt_tokens,
        
        -- Token cost calculations with numeric division precision and fallback handling for missing model pricing
        (messages.prompt_tokens * COALESCE(models.prompt_price_per_1k, 0.0) / 1000.0) AS prompt_cost,
        messages.completion_tokens,
        (messages.completion_tokens * COALESCE(models.completion_price_per_1k, 0.0) / 1000.0) AS completion_cost,
        
        messages.prompt_tokens + messages.completion_tokens AS total_tokens,
        (
            (messages.prompt_tokens * COALESCE(models.prompt_price_per_1k, 0.0) / 1000.0) +
            (messages.completion_tokens * COALESCE(models.completion_price_per_1k, 0.0) / 1000.0)
        ) AS total_cost,
        
        message_reviews.rating AS message_rating,
        message_reviews.review_category AS message_review_category,
        messages.created_at
        
    FROM stg_messages AS messages
    LEFT JOIN stg_conversations AS conversations
        ON conversations.conversation_sk = messages.conversation_sk
    LEFT JOIN dim_models AS models
        ON models.model_id = messages.model_id
       AND messages.created_at >= models.dbt_valid_from
       AND messages.created_at < models.dbt_valid_to
    LEFT JOIN stg_message_reviews AS message_reviews
        ON message_reviews.message_id = messages.id
)

SELECT * FROM dim_messages