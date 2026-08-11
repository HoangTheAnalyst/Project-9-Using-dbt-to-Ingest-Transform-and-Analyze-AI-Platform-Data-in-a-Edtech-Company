{{config(
    warn_if = '>= 5',
    error_if = '>= 10'
)
}}

SELECT
    id,
    prompt_tokens,
    completion_tokens,
    _airbyte_extracted_at
FROM {{ source('source_data', 'raw_messages') }}
WHERE (prompt_tokens <= 0 OR completion_tokens < 0)
AND prompt_tokens IS NOT NULL AND completion_tokens IS NOT NULL
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())