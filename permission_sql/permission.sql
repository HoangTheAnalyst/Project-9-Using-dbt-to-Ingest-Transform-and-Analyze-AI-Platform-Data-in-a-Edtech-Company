-- 1. Create Roles
CREATE ROLE IF NOT EXISTS dbt_role;
CREATE ROLE IF NOT EXISTS analyst_role;

-- 2. Analyst Role (Marts Read-Only)
GRANT USAGE ON DATABASE ai_platform_database TO ROLE analyst_role;
GRANT USAGE ON SCHEMA ai_platform_database.marts TO ROLE analyst_role;

GRANT SELECT ON ALL TABLES IN SCHEMA ai_platform_database.marts TO ROLE analyst_role;
GRANT SELECT ON ALL VIEWS IN SCHEMA ai_platform_database.marts TO ROLE analyst_role;

-- CRITICAL: Ensures access persists when dbt recreates tables/views
GRANT SELECT ON FUTURE TABLES IN SCHEMA ai_platform_database.marts TO ROLE analyst_role;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ai_platform_database.marts TO ROLE analyst_role;

-- 3. dbt Role (Full Pipeline Access)
GRANT USAGE ON DATABASE ai_platform_database TO ROLE dbt_role;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ai_platform_database TO ROLE dbt_role;

GRANT ALL PRIVILEGES ON SCHEMA ai_platform_database.raw TO ROLE dbt_role;
GRANT ALL PRIVILEGES ON SCHEMA ai_platform_database.staging TO ROLE dbt_role;
GRANT ALL PRIVILEGES ON SCHEMA ai_platform_database.marts TO ROLE dbt_role;

GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE dbt_role;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE analyst_role;

-- 4. Assign Roles to Users
GRANT ROLE analyst_role TO USER user_a;
GRANT ROLE dbt_role TO USER user_b;




