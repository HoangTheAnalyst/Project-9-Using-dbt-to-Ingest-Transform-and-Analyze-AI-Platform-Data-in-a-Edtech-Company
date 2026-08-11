{{config(
    warn_if = '>= 10',
    error_if = '>= 100'
)
}}

SELECT
    user_id,
    start_of_newest_plan,
    _airbyte_extracted_at
FROM {{ ref('stg_users') }}
WHERE start_of_newest_plan = _airbyte_extracted_at
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())