{{config(
    error_if = '>= 1'
)
}}

SELECT
    id,
    _airbyte_extracted_at
FROM {{ ref('stg_models') }}
WHERE id = 'unknown_model'
AND(is_active = TRUE OR provider != 'unknown_provider')