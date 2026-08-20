# Project Structure

```text
Project-9-Using-dbt-to-Ingest-Transform-and-Analyze-AI-Platform-Data-in-a-Edtech-Company/
├── .github/
│   └── workflows/
│       └── daily_dbt_pipeline_execution.yml  # CI/CD: Automated daily pipeline execution & tests
├── AI_dbt_transformation_and_create_dim_fact/
│   ├── .vscode/
│   ├── macros/
│   │   └── generate_schema_name.sql          # Custom macro to manage custom schema environments
│   ├── models/
│   │   ├── marts/                            # Dimensional modeling layer (Star Schema / Production)
│   │   │   ├── dim_date.sql
│   │   │   ├── dim_models.sql
│   │   │   ├── dim_users.sql
│   │   │   ├── fct_messages.sql
│   │   │   └── schema.yml                    # Marts documentation, primary key tests & descriptions
│   │   └── staging/                          # Data cleaning, deduplication & renaming layer
│   │       ├── schema.yml                    # Staging column-level tests & model documentation
│   │       ├── source.yml                    # Raw source definitions & freshness configurations
│   │       ├── stg_app_reviews.sql
│   │       ├── stg_conversations.sql
│   │       ├── stg_date.sql
│   │       ├── stg_message_reviews.sql
│   │       ├── stg_messages.sql
│   │       ├── stg_models.sql
│   │       ├── stg_plans.sql
│   │       └── stg_users.sql
│   ├── snapshots/
│   ├── tests/
│   ├── .gitignore
│   ├── dbt_project.yml                       # Core project configurations & materialization rules
│   ├── package-lock.yml
│   └── packages.yml                          # External dbt dependencies
├── docs/
├── images/
├── logs/
│   ├── dbt.log
│   └── query_log.sql
├── permission_sql/
│   └── snowflake_ permission.sql             # Role-Based Access Control (RBAC) & grant scripts
├── .gitignore
├── README.md                                 # Comprehensive project case study & documentation
└── requirements.txt                          # Python dependencies
```