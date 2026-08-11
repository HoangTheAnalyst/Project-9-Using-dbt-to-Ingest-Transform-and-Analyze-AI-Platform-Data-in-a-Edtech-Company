{{config(
    error_if = '>= 1'
)
}}


SELECT
    message_id,
    total_cost,
    (prompt_cost + completion_cost) AS calculated_total_cost
FROM {{ ref('fct_messages') }}
WHERE ABS(total_cost - (prompt_cost + completion_cost)) > 0.00001