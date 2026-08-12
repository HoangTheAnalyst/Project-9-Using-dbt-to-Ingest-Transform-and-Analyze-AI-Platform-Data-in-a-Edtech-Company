# Architecture Decision Records (ADR)

This document details the architectural decisions, trade-offs, and design rationales governing the data engineering pipeline, modeling strategies, and testing frameworks for the AI Platform Data Infrastructure.

---

## ADR-01: Synthetic OLTP Data Generation vs. Public Datasets

* **Context**: Public datasets and online data dumps rarely provide a fully normalized, relational OLTP structure with operational telemetry (such as real-time interaction logs, token usage, and granular message-level feedback).
* **Decision**: Architected and generated a custom, fully normalized PostgreSQL OLTP database from scratch, specifically tailored to an EdTech AI Platform business context.
* **Rationale**:
  * **Business Control**: Allows explicit definition of domain-specific business rules, token consumption quotas, error distributions, and subscription behaviors.
  * **Automated Data Streaming**: Enables seamless daily incremental data generation using GitHub Actions, ensuring full control over upstream source schemas and data production schedules.

---

## ADR-02: Staging Strategy for User Profiles (`user_subscriptions` vs. `users`)

* **Context**: The raw PostgreSQL database separates core user authentication (`users`) from active subscription status (`user_subscriptions`).
* **Decision**: Derive `stg_users` directly from `user_subscriptions` and omit `users` from the core dimensional pipeline.
* **Rationale**:
  * **PII & Low Analytical Value**: The `users` table primarily contains PII and authentication credentials (name, email, password hashes), which must be masked or removed for analytics.
  * **Resource Efficiency**: Joining `users` with `user_subscriptions` in the transformation layer adds processing overhead without contributing actionable metrics. Because analytics focus on token consumption, message volume, and active plan tiers, `user_subscriptions` provides all required attributes for `dim_users`.

---

## ADR-03: Differentiated Data Quality Assertions (Strict Entity Auditing vs. Transactional Thresholds)

* **Context**: Data quality anomalies impact core business entities differently than high-volume transaction streams.
* **Decision**: Enforce a strict **Zero-Tolerance Fail-Fast Policy** (1 invalid record triggers pipeline failure) for entity tables (`users`, `plans`, `models`), while applying **Threshold-Based Warning Tolerances** (10–100 record thresholds) for high-volume event tables (`messages`, `message_reviews`).
* **Rationale**:
  * **Operational Impact**: Entities directly govern core platform functionality. A single corrupted entity record indicates a critical upstream OLTP failure affecting many users.
  * **Pipeline Resilience**: High-volume interaction logs can contain minor transient errors. Setting a reasonable tolerance threshold prevents non-critical log dropouts from crashing daily production builds, while automated warning alerts ensure tracking and remediation.

---

## ADR-04: Null Record Handling (Strict Entity Retention vs. Transaction Cleansing)

* **Context**: `NULL` values in key columns require distinct handling depending on whether they occur in entity or fact data.
* **Decision**: Prohibit silent filtering of `NULL` records in entity models (`users`, `plans`, `models`), while allowing controlled `NULL` filtering or imputation in transactional staging tables.
* **Rationale**:
  * **Silent Data Loss Risk**: Silently filtering `NULL` rows in entity tables masks critical upstream bugs (e.g., lost user accounts, unpriced LLM models, revoked subscription windows). Pipeline failures are necessary to force root-cause fixes.
  * **Analytical Stream Continuity**: In transaction streams (`messages`), missing metadata or orphan rows are filtered or routed to fallbacks to maintain downstream analytical pipeline flow without halting reports.

---

## ADR-05: Adoption of Medallion Architecture without an Intermediate Layer

* **Context**: Designing the dbt transformation layers for simplicity, maintainability, and execution speed.
* **Decision**: Implement a streamlined 3-tier **Medallion Architecture** (`Raw` $\rightarrow$ `Staging` $\rightarrow$ `Marts`), deliberately omitting the `Intermediate` (`int_*`) layer.
* **Rationale**:
  * **Transformation Complexity**: The underlying event streams are straightforward. Apart from `fct_messages`, transformation models do not require complex multi-stage joins or heavy pre-aggregations, making an intermediate layer unnecessary overhead.

---

## ADR-06: Selective SCD Type 2 Implementation (`dim_models` vs. `users` / `plans`)

* **Context**: Historical state changes must be preserved for accurate historical financial and usage reporting.
* **Decision**: Apply **Slowly Changing Dimension Type 2 (SCD Type 2)** snapshotting exclusively to `dim_models`. Maintain current-state snapshotting for `users` and `plans`.
* **Rationale**:
  * **Model Cost Accuracies**: LLM providers (OpenAI, Anthropic) update API pricing frequently. Calculating historical API costs requires matching each message to the model pricing active at the exact creation timestamp.
  * **User & Plan Dynamics**: Mutable user fields (email, name) are non-analytical PII. Subscription plans are offered internally as course-bundled incentives rather than standalone SaaS subscriptions, rendering historical plan versioning unnecessary for token usage analytics.

---

## ADR-07: Zero-Tolerance Quality Gates at the Marts Layer

* **Context**: Ensuring data in production marts (`dim_*`, `fct_*`) is sanitized for downstream Power BI and analyst consumption.
* **Decision**: Configure all generic data tests (`not_null`, `unique`, `relationships`) in the Marts layer to fail on a single failing record (`severity: error`).
* **Rationale**:
  * **Production Guardrail**: The Marts layer is the final gate before data reaches business tools. Because upstream staging models sanitize data and handle missing keys, any remaining `NULL` or duplicate key in Marts indicates a broken transformation or join logic that cannot be passed to analysts.

---

## ADR-08: Sentinel Records for Foreign Key Fallbacks

* **Context**: Messages referencing deleted or unmapped upstream entities risk being dropped during inner joins or creating dangling foreign keys.
* **Decision**: Inject synthetic **Sentinel / Default Records** (e.g., `unknown_model`, ID = `-1`) into entity models and `conversations`.
* **Rationale**:
  * **Orphan Key Protection**: When a message references an unknown or missing model/user ID, `COALESCE` maps the foreign key to the sentinel row. This prevents record loss in star-schema queries while maintaining referential integrity across dimensional joins.

---

## ADR-09: Point-in-Time Joins for SCD Type 2 Foreign Keys (`model_sk`)

* **Context**: Joining fact events to SCD Type 2 dimensions requires mapping to the correct surrogate key version based on timestamps.
* **Decision**: Do not hash `model_id` directly in `stg_messages`. Instead, construct `model_sk` in `fct_messages` via point-in-time timestamp range joins:
  `created_at >= dbt_valid_from AND created_at < dbt_valid_to`.
* **Rationale**:
  * **Surrogate Key Mismatch**: `dim_models` surrogate keys (`model_sk`) are generated by hashing `model_id` + `dbt_updated_at`. Because `stg_messages` only contains the interaction timestamp (`created_at`), hashing `model_id` alone on the message table produces an invalid surrogate key. A point-in-time date range join is required to retrieve the correct `model_sk`.