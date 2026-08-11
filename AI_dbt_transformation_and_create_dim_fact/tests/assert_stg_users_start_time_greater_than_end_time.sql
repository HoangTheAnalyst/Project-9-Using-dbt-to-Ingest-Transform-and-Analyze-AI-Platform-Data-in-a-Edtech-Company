{{config(
    warn_if = '>= 1',
    error_if = '>= 5'
)
}}

SELECT
    user_id,
    start_of_newest_plan,
    end_of_newest_plan
FROM {{ ref('stg_users') }}
WHERE start_of_newest_plan IS NOT NULL 
AND end_of_newest_plan IS NOT NULL 
AND start_of_newest_plan > end_of_newest_plan
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())