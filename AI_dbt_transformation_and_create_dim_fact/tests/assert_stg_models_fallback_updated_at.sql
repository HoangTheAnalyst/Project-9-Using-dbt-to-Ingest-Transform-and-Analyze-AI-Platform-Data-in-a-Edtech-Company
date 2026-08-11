{{config(
    warn_if = '>= 1',
    error_if = '>= 2'
)
}}

SELECT
    id AS model_id,
    _airbyte_extracted_at
FROM {{ ref('stg_models') }}
WHERE updated_at = _airbyte_extracted_at
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())

