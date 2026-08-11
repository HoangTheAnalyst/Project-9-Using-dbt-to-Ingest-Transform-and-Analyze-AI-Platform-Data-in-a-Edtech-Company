{{ config(
    materialized='table',
    schema='staging'
) }}

-- Writing macro to generate a date dimension table for the range 2020-01-01 to 2030-12-31
{{ dbt_date.get_date_dimension('2020-01-01', '2030-12-31') }} 