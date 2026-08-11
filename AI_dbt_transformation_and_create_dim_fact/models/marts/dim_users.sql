{{ config(
    materialized = 'table',
    schema = 'marts'
) }}

/*
  MODEL: dim_users
  PURPOSE: 
    1. Dimension table capturing user profiles, active subscription plan details, and app feedback metrics.
    2. Consolidates user attributes with master plan categories and latest satisfaction ratings for dimensional reporting.
*/

WITH users AS (
    SELECT
        user_id,
        user_sk,
        newest_plan_id,
        start_of_newest_plan,
        end_of_newest_plan
    FROM {{ ref('stg_users') }}
),

plans AS (
    SELECT
        id,
        plan_type
    FROM {{ ref('stg_plans') }}
),

user_reviews AS (
    SELECT
        user_sk,
        latest_rating
    FROM {{ ref('stg_app_reviews') }}
)

SELECT
    users.user_id,
    users.user_sk,
    users.newest_plan_id,
    plans.plan_type AS newest_plan_type,
    users.start_of_newest_plan,
    users.end_of_newest_plan,
    
    -- Latest application rating provided by user (NULL indicates no submitted app review)
    user_reviews.latest_rating

FROM users
LEFT JOIN plans
    ON plans.id = users.newest_plan_id
LEFT JOIN user_reviews
    ON user_reviews.user_sk = users.user_sk