{{config(
    error_if = '>= 1'
)
}}

SELECT
    id,
    prompt_price_per_1k,
    completion_price_per_1k
FROM {{ ref('stg_models') }}
WHERE prompt_price_per_1k IS NOT NULL
AND completion_price_per_1k IS NOT NULL
AND (prompt_price_per_1k < 0 OR prompt_price_per_1k > 1
OR completion_price_per_1k < 0 OR completion_price_per_1k > 1)
AND _airbyte_extracted_at >= DATEADD(day, -1, CURRENT_TIMESTAMP())