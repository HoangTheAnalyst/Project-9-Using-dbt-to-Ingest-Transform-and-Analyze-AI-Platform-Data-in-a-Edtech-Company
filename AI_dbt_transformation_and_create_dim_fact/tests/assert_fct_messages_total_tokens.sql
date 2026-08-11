{{config(
    error_if = '>= 1'
)
}}

SELECT
    message_id,
    total_tokens,
    (prompt_tokens + completion_tokens) AS calculated_total_tokens
FROM {{ ref('fct_messages') }}
WHERE ABS(total_tokens - (prompt_tokens + completion_tokens)) > 1