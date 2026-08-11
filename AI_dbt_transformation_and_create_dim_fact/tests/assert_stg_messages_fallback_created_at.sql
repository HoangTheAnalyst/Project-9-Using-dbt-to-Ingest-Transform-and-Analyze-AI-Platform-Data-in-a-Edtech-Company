{{config(
    warn_if = '>= 10',
    error_if = '>= 100'
)
}}

SELECT
    id AS message_id,
    _airbyte_extracted_at
FROM {{ ref('stg_messages') }}
WHERE created_at = _airbyte_extracted_at
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())