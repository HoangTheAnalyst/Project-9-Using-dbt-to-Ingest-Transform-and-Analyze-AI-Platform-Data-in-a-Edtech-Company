# Deployment & Setup Guide on dbt, Snowflake & GitHub Actions


### Prerequisites
* **Python 3.10+**
* **Snowflake Account** with permissions to execute transformation workloads.
* **Airbyte Instance** (Cloud or Self-Hosted).
* **Neon DB** (Serverless PostgreSQL) source database instance.

---

### Step 0: Airbyte Ingestion Pipeline Setup

Before running dbt transformations, populate the raw landing zone in Snowflake via Airbyte:
1 **Create Database & Schema**:On Snowflake, create database `AI_PLATFORM_DATABASE`. In there, create 5 schemas: `raw`, `staging`, `marts`, `tests` and `snapshots` to save the result tables.
2. **Source Connection**: Connect Airbyte to Neon DB PostgreSQL source.
3. **Destination Connection**: Connect Airbyte to Snowflake:
   * **Database**: `AI_PLATFORM_DATABASE`
   * **Default Schema**: `RAW`
   * **Warehouse**: `COMPUTE_WH`
4. **Connection Configuration**: 
   * Set replication stream for all 8 transactional tables (`users`, `user_subscriptions`, `conversations`, `messages`, `app_reviews`, `message_reviews`, `plans`, `models`).
   * Choose **Incremental / Append-Deduplicate** mode for event tables (`messages`, `message_reviews`) and **Full Refresh** for entity tables.
5. **Trigger Initial Sync**: Run the Airbyte connection manually to ensure all raw payloads land in `AI_PLATFORM_DATABASE.RAW`.

---

### Step 1: Clone Repository & Virtual Environment Setup

```bash
# Clone the dbt project repository
git clone <your-dbt-project-repo-url>

# Initialize virtual environment
python -m venv venv

# Activate environment (Windows PowerShell)
.\venv\Scripts\Activate.ps1

# Activate environment (Linux / macOS)
source venv/bin/activate
```

---

### Step 2: Install Production Dependencies

```bash
pip install --upgrade pip
pip install dbt-core dbt-snowflake (or pip install -r requirements.txt)
```

---

### Step 3: Configure dbt Profile (`profiles.yml`)

Create or verify `profiles.yml` inside your project root directory or `~/.dbt/`:

```yaml
AI_dbt_transformation_and_create_dim_fact:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_snowflake_account_identifier>
      user: <your_username>
      password: <your_password>
      role: accountadmin
      database: AI_PLATFORM_DATABASE
      warehouse: COMPUTE_WH
      schema: marts
      threads: 16
```

---

### Step 4: Execute Local dbt Build

Test connection, install dbt packages, and run transformations with data quality tests:

```bash
#Move to dbt project folder:
cd AI_dbt_transformation_and_create_dim_fact

# Verify Snowflake connection and profile setup
dbt debug --profiles-dir .

# Install package dependencies
dbt deps

# Run transformations and data quality tests in a single pass
dbt build --profiles-dir .
```

---

### Step 5: Configure GitHub Actions Secrets

To enable scheduled automated runs, add these repository secrets (`Settings > Secrets and variables > Actions`):

* `SNOWFLAKE_ACCOUNT`: Snowflake account identifier
* `SNOWFLAKE_USER`: Dedicated CI/CD Snowflake user
* `SNOWFLAKE_PASSWORD`: User authentication password
* `SNOWFLAKE_ROLE`: Pipeline role (`dbt_role`)
* `SNOWFLAKE_DATABASE`: Target database (`AI_PLATFORM_DATABASE`)
* `SNOWFLAKE_WAREHOUSE`: Compute warehouse (`COMPUTE_WH`)

> The daily workflow runs automatically via `.github/workflows/dbt_daily_run.yml` in 19:15 UTC (or you can reschedule on `.github/workflows/daily_dbt_pipeline_execution.yml`)

---

### Step 6: (Optional) Configure Snowflake RBAC & Security Grants

If deploying in a multi-user corporate environment, run this SQL script in Snowflake Console as `ACCOUNTADMIN` to set up production Role-Based Access Control and isolate data schemas: [Permission.sql](../permission_sql/permission.sql)
