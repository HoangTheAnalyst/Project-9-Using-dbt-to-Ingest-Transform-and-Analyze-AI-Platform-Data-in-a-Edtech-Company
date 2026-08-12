# Data Dictionary - Gold Layer (Marts)

This document provides schema specifications, data types, key designations, and business rules for all Dimension and Fact tables in the Marts layer (`dim_*`, `fct_*`).

---

## 1. Dimension Table: `dim_models` (SCD Type 2)

* **Description**: Tracks AI model catalog metadata, active status, and historical changes in token pricing over time using dbt SCD Type 2 snapshotting.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`model_sk`** | `VARCHAR(32)` | **PK / SK** | Surrogate Key uniquely identifying each historical pricing version of an AI model. |
| **`model_id`** | `VARCHAR(50)` | **NK** | Natural Key identifying the model from source system (e.g., `gpt-4o`, `claude-3-5-sonnet`). |
| **`provider`** | `VARCHAR(100)` | - | AI service provider (e.g., `OpenAI`, `Anthropic`). |
| **`is_model_active`** | `BOOLEAN` | **Flag** | Source status flag indicating if the model is active (`TRUE`) or deprecated (`FALSE`). |
| **`updated_at`** | `TIMESTAMP` | - | Timestamp when model metadata was last modified in source system. |
| **`prompt_price_per_1k`** | `FLOAT` | - | Unit price per 1,000 Prompt/Input Tokens in USD. |
| **`completion_price_per_1k`** | `FLOAT` | - | Unit price per 1,000 Completion/Output Tokens in USD. |
| **`dbt_valid_from`** | `TIMESTAMP` | - | Effective start timestamp when this pricing version became active. |
| **`dbt_valid_to`** | `TIMESTAMP` | - | Expiration timestamp for this pricing version (`NULL` indicates current active version). |
| **`is_current`** | `BOOLEAN` | **Flag** | Version indicator: `TRUE` (Active version), `FALSE` (Historical version). |

---

## 2. Dimension Table: `dim_users` (Current Snapshot)

* **Description**: Stores consolidated user profile records, current subscription plan tiers, effective plan validity windows, and latest submitted app ratings.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`user_sk`** | `VARCHAR(32)` | **PK / SK** | Surrogate Key uniquely identifying each user record. |
| **`user_id`** | `VARCHAR(80)` | **NK** | Natural Key identifying the user from PostgreSQL source. |
| **`newest_plan_id`** | `VARCHAR(50)` | **FK** | Foreign key referencing `stg_plans.id` for user's most recent subscription plan. |
| **`newest_plan_type`** | `VARCHAR(50)` | - | Categorization of latest subscription tier (`Free`, `Basic`, `Ultra`). |
| **`start_of_newest_plan`** | `TIMESTAMP` | - | Effective start timestamp of user's active/newest subscription plan. |
| **`end_of_newest_plan`** | `TIMESTAMP` | - | Expiration timestamp of user's active/newest subscription plan. |
| **`latest_rating`** | `VARCHAR(10)` | - | Latest application review rating submitted by user (`NULL` if no review submitted). |

---

## 3. Dimension Table: `dim_date` (Calendar Dimension)

* **Description**: Standard calendar dimension enabling daily, weekly, monthly, and quarterly time-series aggregations across fact tables.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`date_key`** | `NUMBER` | **PK** | Primary Key formatted as `YYYYMMDD` integer (e.g., `20260811`). |
| **`date_day`** | `DATE` | - | Standard calendar date (`YYYY-MM-DD`). |
| **`day_of_month`** | `INT` | - | Day number within the month (`1` to `31`). |
| **`day_of_week_name_short`** | `VARCHAR(10)` | - | Abbreviated day of week name (e.g., `Mon`, `Tue`). |
| **`week_of_year`** | `INT` | - | ISO calendar week number (`1` to `53`). |
| **`week_start_date`** | `DATE` | - | Start date of the week (`Monday`). |
| **`month_of_year`** | `INT` | - | Calendar month number (`1` to `12`). |
| **`month_name_short`** | `VARCHAR(10)` | - | Abbreviated month name (e.g., `Jan`, `Aug`). |
| **`month_start_date`** | `DATE` | - | First calendar date of the month. |
| **`month_end_date`** | `DATE` | - | Last calendar date of the month. |
| **`quarter_of_year`** | `INT` | - | Calendar quarter (`1` to `4`). |
| **`year_number`** | `INT` | - | Four-digit calendar year (e.g., `2026`). |

---

## 4. Fact Table: `fct_messages` (Transaction Fact)

* **Description**: Central fact table storing granular prompt-response interaction events, token consumption metrics, calculated API expenditures, and user message feedback.

| Column Name | Data Type | Key Type | Description & Business Rules |
| :--- | :--- | :--- | :--- |
| **`message_id`** | `VARCHAR(80)` | **PK** | Unique identifier for the message transaction. |
| **`date_key`** | `NUMBER` | **FK** | Foreign key formatted as `YYYYMMDD` linking to `dim_date.date_key`. |
| **`conversation_sk`** | `VARCHAR(32)` | **FK** | Surrogate key linking to the parent conversation session. |
| **`user_sk`** | `VARCHAR(32)` | **FK** | Foreign key referencing `dim_users.user_sk`. |
| **`model_id`** | `VARCHAR(50)` | **NK** | Model string identifier with `COALESCE` fallback (`unknown_model`). |
| **`model_sk`** | `VARCHAR(32)` | **FK / SK** | Point-in-time foreign key joining `dim_models` based on message creation timestamp (`created_at >= dbt_valid_from AND created_at < dbt_valid_to`). Fallback to `MD5('unknown_model')` if pricing is missing. |
| **`is_error`** | `BOOLEAN` | **Flag** | System error indicator: `TRUE` (Error), `FALSE` (Success). |
| **`is_user_prompt`** | `BOOLEAN` | **Flag** | Message direction flag: `TRUE` (User input prompt), `FALSE` (AI response). |
| **`is_user_uploaded_file`** | `BOOLEAN` | **Flag** | Input attachment flag: `TRUE` (User attached a file), `FALSE` (None). |
| **`is_model_answer_file`** | `BOOLEAN` | **Flag** | Output attachment flag: `TRUE` (AI generated an output file), `FALSE` (None). |
| **`is_model_answer_text`** | `BOOLEAN` | **Flag** | Output text flag: `TRUE` (AI generated text content), `FALSE` (None). |
| **`prompt_tokens`** | `INT` | **Measure** | Number of input prompt tokens consumed. |
| **`prompt_cost`** | `FLOAT` | **Measure** | Calculated input token cost in USD = `(prompt_tokens * prompt_price_per_1k) / 1000.0`. |
| **`completion_tokens`** | `INT` | **Measure** | Number of output completion tokens generated. |
| **`completion_cost`** | `FLOAT` | **Measure** | Calculated output token cost in USD = `(completion_tokens * completion_price_per_1k) / 1000.0`. |
| **`total_tokens`** | `INT` | **Measure** | Total message tokens = `prompt_tokens + completion_tokens`. |
| **`total_cost`** | `FLOAT` | **Measure** | Total message API expenditure in USD = `prompt_cost + completion_cost`. |
| **`message_rating`** | `VARCHAR(10)` | - | User feedback rating score recorded for this specific message. |
| **`message_review_category`**| `VARCHAR(100)`| - | Primary feedback category assigned to the message review. |
| **`created_at`** | `TIMESTAMP` | - | Timestamp when the message interaction was created. |