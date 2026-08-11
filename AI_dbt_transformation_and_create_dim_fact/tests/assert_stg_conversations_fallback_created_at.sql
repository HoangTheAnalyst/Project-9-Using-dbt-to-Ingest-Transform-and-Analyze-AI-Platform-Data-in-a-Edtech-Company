{{config(
    warn_if = '>= 5',
    error_if = '>= 50'
)
}}

SELECT
    id AS conversation_id,
    _airbyte_extracted_at
FROM {{ ref('stg_conversations') }}
WHERE created_at = _airbyte_extracted_at
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())