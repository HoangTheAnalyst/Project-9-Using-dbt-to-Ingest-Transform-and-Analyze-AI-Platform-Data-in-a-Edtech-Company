{{ config(
    materialized='table',
    schema='marts'
) }}

SELECT
    date_day,                -- Primary Key (2026-08-11)
    day_of_month,            -- 11
    day_of_week_name_short,  -- Tue  
    week_of_year,            -- 33
    week_start_date,         -- 2026-08-10 
    month_of_year,           -- 8
    month_name_short,        -- Aug
    month_start_date,        -- 2026-08-01
    month_end_date,          -- 2026-08-31 
    quarter_of_year,         -- 3
    year_number              -- 2026
FROM {{ref('stg_date')}}


