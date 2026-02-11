# Modern Data Warehouse Stack
## Complete Architecture & Implementation Workshop

---

# Agenda (60 minutes)

| Time | Topic |
|------|-------|
| 0:00 - 0:05 | Introduction & Business Value |
| 0:05 - 0:15 | Architecture Overview |
| 0:15 - 0:25 | Data Pipeline: Source → Ingestion → Transform |
| 0:25 - 0:35 | Analytics Layer: Dashboards & AI |
| 0:35 - 0:45 | Security & Access Control |
| 0:45 - 0:55 | Live Demo & Operations |
| 0:55 - 1:00 | Q&A and Next Steps |

---

# Part 1: Introduction
## (5 minutes)

---

# What is a Modern Data Stack?

### Traditional vs Modern

| Traditional | Modern Data Stack |
|-------------|-------------------|
| Monolithic ETL tools | Modular, best-of-breed tools |
| On-premise servers | Cloud-native & containerized |
| SQL-only analytics | SQL + AI/ML integration |
| Static reports | Interactive dashboards |
| Manual access control | Policy-as-code authorization |

---

# Our Data Warehouse Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          𝗠𝗼𝗱𝗲𝗿𝗻 𝗗𝗮𝘁𝗮 𝗪𝗮𝗿𝗲𝗵𝗼𝘂𝘀𝗲 𝗦𝘁𝗮𝗰𝗸                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐               │
│   │  SQL Server │    │   Airbyte   │    │ PostgreSQL  │               │
│   │ (Adventure  │───►│    (EL)     │───►│   (Data     │               │
│   │   Works)    │    │             │    │  Warehouse) │               │
│   └─────────────┘    └─────────────┘    └──────┬──────┘               │
│       Source            Extract              Storage                   │
│                          Load                                          │
│                                                │                        │
│                                        ┌───────▼───────┐              │
│                                        │     dbt       │              │
│                                        │  (Transform)  │              │
│                                        └───────┬───────┘              │
│                                                │                        │
│                    ┌───────────────────────────┼───────────────────┐   │
│                    │                           │                    │   │
│            ┌───────▼───────┐           ┌──────▼──────┐            │   │
│            │   Streamlit   │           │  dbt Docs   │            │   │
│            │  (Dashboard)  │           │             │            │   │
│            └───────┬───────┘           └─────────────┘            │   │
│                    │                                                │   │
│            ┌───────▼───────┐                                       │   │
│            │ AI Assistant  │                                       │   │
│            │  (GPT-4/Claude)                                       │   │
│            └───────┬───────┘                                       │   │
│                    │                                                │   │
│            ┌───────▼───────┐                                       │   │
│            │   OPA/OPAL    │                                       │   │
│            │ (AuthZ)       │                                       │   │
│            └───────────────┘                                       │   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Source** | SQL Server + AdventureWorks | Enterprise sample data |
| **Extract/Load** | Airbyte | Data ingestion |
| **Storage** | PostgreSQL 16 | Data warehouse |
| **Transform** | dbt Core | Data modeling (ELT) |
| **Visualization** | Streamlit | Interactive dashboards |
| **AI** | OpenAI GPT-4 / Claude | Natural language queries |
| **Security** | OPA + OPAL | Policy-based access control |
| **Deployment** | Docker Compose | Container orchestration |

---

# Business Value

### For Data Teams
- ⚡ **Fast Setup** - Start to dashboards in hours, not weeks
- 🔄 **Modern ELT** - Transform in warehouse, not during load
- 📊 **Self-Service BI** - Interactive dashboards

### For Business Users  
- 🤖 **AI Analytics** - Ask questions in plain English
- 📈 **Real-time Insights** - Always up-to-date data
- 🔐 **Secure** - Role-based access control

### For IT/Engineering
- 🐳 **Containerized** - Easy deployment & scaling
- 📝 **Code-based** - Version controlled, reproducible
- 🔌 **Modular** - Swap components as needed

---

# Part 2: Architecture Overview
## (10 minutes)

---

# High-Level Architecture

```
                    ┌──────────────────────────────────────┐
                    │           Data Sources                │
                    │  ┌──────────┐  ┌──────────┐         │
                    │  │SQL Server│  │  APIs    │  ...    │
                    │  │Adventure │  │          │         │
                    │  │  Works   │  │          │         │
                    │  └────┬─────┘  └────┬─────┘         │
                    └───────┼─────────────┼───────────────┘
                            │             │
                            ▼             ▼
                    ┌──────────────────────────────────────┐
                    │         Airbyte (EL Layer)           │
                    │   • 300+ connectors                  │
                    │   • Incremental sync                 │
                    │   • Schema detection                 │
                    └─────────────────┬────────────────────┘
                                      │
                                      ▼
                    ┌──────────────────────────────────────┐
                    │     PostgreSQL (Data Warehouse)      │
                    │  ┌────────────────────────────────┐  │
                    │  │  Raw Schema: humanresources,   │  │
                    │  │  production, purchasing, sales │  │
                    │  └────────────────────────────────┘  │
                    └─────────────────┬────────────────────┘
                                      │
                                      ▼
                    ┌──────────────────────────────────────┐
                    │          dbt (Transform)             │
                    │  staging → intermediate → marts      │
                    └─────────────────┬────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ▼                       ▼                       ▼
    ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
    │   Streamlit     │     │   dbt Docs      │     │   OPA/OPAL      │
    │   Dashboard     │     │   (Catalog)     │     │   (Security)    │
    └─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

# Service Architecture

| Service | Port | Container | Purpose |
|---------|------|-----------|---------|
| PostgreSQL | 5432 | `data_warehouse_postgres` | Data storage |
| Streamlit | 8501 | `data_warehouse_streamlit` | Dashboard UI |
| dbt Docs | 8080 | `data_warehouse_dbt_docs` | Data catalog |
| SQL Server | 1433 | `data_warehouse_sqlserver` | Source database |
| Airbyte | 8000 | `airbyte-abctl-*` | Data ingestion |
| OPA | 8181 | `opal-opa-standalone` | Policy engine |
| OPAL Server | 7002 | `opal-server` | Policy admin |

---

# Docker Compose Overview

```yaml
services:
  postgres:          # Data warehouse storage
    image: postgres:16-alpine
    ports: ["5432:5432"]
    
  streamlit:         # Analytics dashboard
    build: ./streamlit
    ports: ["8501:8501"]
    depends_on: [postgres]
    
  dbt-docs:          # Data documentation
    build: ./dbt
    ports: ["8080:80"]
    depends_on: [postgres]
    
  sqlserver:         # Source database
    image: mcr.microsoft.com/mssql/server:2022
    ports: ["1433:1433"]
```

---

# Data Flow

```
Step 1: Source Data (SQL Server)
         │
         │  AdventureWorks Database
         │  • HumanResources (employees, departments)
         │  • Production (products, inventory, work orders)
         │  • Purchasing (vendors, purchase orders)
         │  • Sales (customers, orders, territories)
         │
         ▼
Step 2: Extract & Load (Airbyte)
         │
         │  • Full refresh or incremental sync
         │  • Schema auto-detection
         │  • Data type mapping
         │
         ▼
Step 3: Transform (dbt)
         │
         │  Raw → Staging → Intermediate → Marts
         │
         ▼
Step 4: Consume (Streamlit + AI)
```

---

# Part 3: Data Pipeline
## Source → Ingestion → Transform (10 minutes)

---

# Data Source: AdventureWorks

### What is AdventureWorks?
Microsoft's sample enterprise database representing a fictional bicycle company

### Database Schemas

| Schema | Description | Key Tables |
|--------|-------------|------------|
| **HumanResources** | Employee data | Employee, Department, JobCandidate |
| **Production** | Manufacturing | Product, WorkOrder, BillOfMaterials |
| **Purchasing** | Procurement | Vendor, PurchaseOrderHeader |
| **Sales** | Sales operations | Customer, SalesOrderHeader, Territory |
| **Person** | Contact info | Person, Address, EmailAddress |

---

# AdventureWorks Data Model

```
                    ┌─────────────────┐
                    │     Person      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Customer    │   │   Employee    │   │    Vendor     │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ SalesOrder    │   │   WorkOrder   │   │ PurchaseOrder │
│   Header      │   │               │   │    Header     │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ SalesOrder    │   │   Product     │   │ PurchaseOrder │
│   Detail      │◄──┤               │──►│    Detail     │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

# Data Ingestion: Airbyte

### Why Airbyte?
- 🔌 **300+ Connectors** - Pre-built source/destination connectors
- 🔄 **Incremental Sync** - Only sync changed data
- 📊 **Schema Detection** - Auto-detect and evolve schemas
- 🌐 **Open Source** - No vendor lock-in

### Architecture
```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Sources   │ ───► │   Airbyte   │ ───► │Destinations │
│             │      │   Platform  │      │             │
│ • SQL Server│      │  • Sync Jobs│      │ • PostgreSQL│
│ • APIs      │      │  • Transforms      │ • Snowflake │
│ • Files     │      │  • Scheduling      │ • BigQuery  │
└─────────────┘      └─────────────┘      └─────────────┘
```

---

# Airbyte Configuration

### Connection Setup
```
Source: SQL Server (AdventureWorks)
├── Host: localhost:1433
├── Database: AdventureWorks2022
├── User: sa
└── Schemas: HumanResources, Production, Purchasing, Sales

Destination: PostgreSQL (Data Warehouse)
├── Host: localhost:5432
├── Database: data_warehouse
├── User: postgres
└── Schema: (per source schema)
```

### Sync Modes
- **Full Refresh** - Complete data replacement
- **Incremental** - Append new/updated records
- **CDC** - Change Data Capture (real-time)

---

# Data Transformation: dbt

### What is dbt?
**d**ata **b**uild **t**ool - Transform data using SQL + software engineering best practices

### Key Features
- 📝 **SQL-based** - Write transformations in SQL
- 🔀 **DAG** - Automatic dependency management
- ✅ **Testing** - Built-in data quality tests
- 📚 **Documentation** - Auto-generated data catalog
- 🔄 **Incremental** - Process only new data

---

# dbt Model Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                        dbt Project                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐      ┌─────────────────┐      ┌────────────┐  │
│  │   Staging   │      │  Intermediate   │      │   Marts    │  │
│  │   (88 SQL)  │ ───► │   dim + fact    │ ───► │ (5 tables) │  │
│  │             │      │                 │      │            │  │
│  │  stg_*      │      │  dim_customer   │      │mart_sales  │  │
│  │  (views)    │      │  dim_product    │      │mart_ops    │  │
│  │             │      │  fact_sales     │      │mart_hr     │  │
│  └─────────────┘      └─────────────────┘      └────────────┘  │
│                                                                 │
│  Purpose:             Purpose:                Purpose:          │
│  Clean raw data       Business entities       Analytics-ready   │
│  Rename columns       Relationships           Denormalized      │
│  Cast types           Calculated metrics      Self-service      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# dbt Model Example: Staging

```sql
-- models/staging/sales/stg_sales__salesorderheader.sql

with source as (
    select * from {{ source('sales', 'salesorderheader') }}
),

renamed as (
    select
        salesorderid as sales_order_id,
        revisionnumber as revision_number,
        orderdate as order_date,
        duedate as due_date,
        shipdate as ship_date,
        status as order_status,
        onlineorderflag as is_online_order,
        purchaseordernumber as purchase_order_number,
        customerid as customer_id,
        salespersonid as sales_person_id,
        territoryid as territory_id,
        subtotal,
        taxamt as tax_amount,
        freight,
        totaldue as total_due
    from source
)

select * from renamed
```

---

# dbt Model Example: Mart

```sql
-- models/marts/mart_sales.sql

with sales as (
    select * from {{ ref('fact_sales_order_line') }}
),

customers as (
    select * from {{ ref('dim_customer') }}
),

products as (
    select * from {{ ref('dim_product') }}
),

territories as (
    select * from {{ ref('dim_territory') }}
)

select
    -- Order details
    s.salesorderid,
    s.order_date,
    s.order_total,
    
    -- Customer info
    c.customer_name,
    c.customer_segment,
    
    -- Product info
    p.product_name,
    p.category_name,
    
    -- Territory
    t.territory_name,
    t.countryregioncode,
    
    -- Calculated metrics
    s.net_line_amount,
    s.total_profit,
    s.profit_margin_percent

from sales s
left join customers c on s.customer_key = c.customer_key
left join products p on s.product_key = p.product_key
left join territories t on s.territory_key = t.territory_key
```

---

# dbt Mart Tables

| Mart | Grain | Key Use Cases |
|------|-------|---------------|
| **mart_sales** | Order line item | Revenue, territories, trends |
| **mart_customer_analytics** | Customer | CLV, segmentation, churn |
| **mart_product_analytics** | Product | Profitability, inventory |
| **mart_operations** | Order (PO/WO) | Vendor performance, production |
| **mart_employee_territory_performance** | Employee/period | Sales quotas, territories |

### Analytics Supported
✅ CLV Analysis • ✅ RFM Segmentation • ✅ Churn Prediction  
✅ Inventory Optimization • ✅ Territory Performance • ✅ Time Series

---

# Part 4: Analytics Layer
## Dashboards & AI (10 minutes)

---

# Streamlit Dashboard

### Multi-Page Analytics Application

```
📊 AdventureWorks Analytics Dashboard
├── 🏠 Overview (KPIs, trends, map)
├── 🤖 AI Assistant (NL queries)
├── 💰 Sales & Revenue
├── 📦 Product & Inventory
├── 👥 Customer Analytics
├── 👔 HR & Employee Performance
├── ⚙️ Operations & Supply Chain
├── 🔮 Advanced Analytics
└── 🛡️ OPAL Authorization Demo
```

---

# Dashboard: Sales & Revenue

### Features
- Revenue trends over time
- Territory performance maps
- Product sales analysis
- Customer segmentation charts
- Customer Lifetime Value

### Sample Visualizations
```
┌────────────────────────────────────────────────────────────┐
│  Revenue Trend                    Top Products by Revenue  │
│  📈 ────────────────              ▓▓▓▓▓▓▓▓▓▓ Product A    │
│                                   ▓▓▓▓▓▓▓▓   Product B    │
│                                   ▓▓▓▓▓▓     Product C    │
├────────────────────────────────────────────────────────────┤
│  Territory Performance            Customer Segments        │
│  🗺️ [Interactive Map]            🥧 [Sunburst Chart]      │
└────────────────────────────────────────────────────────────┘
```

---

# AI Analytics Assistant

### Natural Language to SQL

```
User: "What is our revenue by territory?"
         │
         ▼
┌─────────────────────────────────────────┐
│           AI Processing                  │
│  1. Parse natural language              │
│  2. Match to schema context             │
│  3. Generate SQL query                  │
│  4. Validate for safety                 │
│  5. Execute against database            │
│  6. Visualize results                   │
└─────────────────────────────────────────┘
         │
         ▼
SQL: SELECT territory_name, SUM(order_total) as revenue
     FROM mart_sales GROUP BY territory_name
         │
         ▼
📊 [Auto-generated bar chart]
```

---

# AI Assistant Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AI Analytics Assistant                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ schema_context  │    │  sql_generator  │                │
│  │                 │    │                 │                │
│  │ • Table schemas │───►│ • System prompt │                │
│  │ • Metric defs   │    │ • Few-shot SQL  │                │
│  │ • Column info   │    │ • LLM API call  │                │
│  └─────────────────┘    └────────┬────────┘                │
│                                  │                          │
│                                  ▼                          │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  sql_validator  │    │   visualizer    │                │
│  │                 │◄───┤                 │                │
│  │ • SELECT only   │    │ • Auto charts   │                │
│  │ • Whitelist     │    │ • Smart types   │                │
│  │ • No injection  │    │ • Format data   │                │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

# AI Safety & Security

### SQL Validator Rules

| Rule | Description |
|------|-------------|
| **SELECT Only** | No INSERT, UPDATE, DELETE, DROP |
| **Table Whitelist** | Only query allowed tables |
| **Auto LIMIT** | Prevent huge result sets |
| **No Injection** | Block SQL injection patterns |
| **Read-Only** | No DDL operations |

```python
# sql_validator.py
FORBIDDEN_PATTERNS = [
    r'\b(DROP|DELETE|TRUNCATE|ALTER|CREATE)\b',
    r'\b(INSERT|UPDATE)\b',
    r';\s*(DROP|DELETE|SELECT)',  # Multiple statements
    r'--',  # SQL comments (potential injection)
]
```

---

# AI + dbt Auto-Sync

### Automatic Schema Updates

```bash
cd dbt
./run_dbt.sh run

# Output:
# 🔄 Syncing AI components with dbt models...
# ✅ Generated schema_ai.md (15,234 chars, ~3,800 tokens)
# ✅ Generated allowed_tables.json (23 tables)
```

### Generated Files
- `dbt/models/schema_ai.md` - LLM context (tables, columns, relationships)
- `streamlit/ai/allowed_tables.json` - Whitelist for SQL validator

**No manual updates needed!** New models auto-appear in AI assistant.

---

# Part 5: Security & Access Control
## (10 minutes)

---

# Why Policy-Based Access Control?

### Traditional Approach Problems
- 🔓 Hard-coded permissions in application
- 😰 Scattered logic across codebase  
- 📝 No audit trail
- 🔄 Changes require code deployment

### Policy-as-Code Benefits
- 📝 **Declarative** - Policies in readable format
- 🔐 **Centralized** - Single source of truth
- 📊 **Auditable** - Track all decisions
- ⚡ **Real-time** - Update without deployments

---

# OPA + OPAL Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    Policy Management                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────────┐                                       │
│   │  Git Repository │  ← Policy files (Rego)                │
│   │  (policies/)    │  ← Data files (users.json, roles.json)│
│   └────────┬────────┘                                       │
│            │                                                 │
│            ▼                                                 │
│   ┌─────────────────┐                                       │
│   │  OPAL Server    │  ← Watches for changes                │
│   │  (port 7002)    │  ← Pushes updates                     │
│   └────────┬────────┘                                       │
│            │ WebSocket                                       │
│            ▼                                                 │
│   ┌─────────────────┐                                       │
│   │  OPAL Client    │  ← Receives updates                   │
│   │  + OPA Engine   │  ← Evaluates policies                 │
│   │  (port 8181)    │  ← Returns allow/deny                 │
│   └────────┬────────┘                                       │
│            │                                                 │
│            ▼                                                 │
│   ┌─────────────────┐                                       │
│   │  Applications   │  ← Streamlit, APIs, etc.              │
│   └─────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

# Role-Based Access Control

### User Roles

| Role | Description | Access Level |
|------|-------------|--------------|
| `admin` | System administrator | Full access |
| `data_engineer` | Data pipeline team | All data + write staging |
| `analyst` | Data analysts | Read marts, dashboards, AI |
| `viewer` | Read-only users | Limited dashboards |
| `executive` | Leadership | All dashboards, exports |
| `sales_manager` | Sales team | Sales + customer data |
| `hr_manager` | HR team | Employee data only |
| `operations_manager` | Operations | Inventory + production |

---

# Rego Policy Example

```rego
package datawarehouse.authz

default allow := false

# Admin full access
allow if {
    "admin" in user_roles
}

# Dashboard access by role
allow if {
    input.action == "view"
    input.resource == "dashboard.sales"
    {"sales_manager", "executive", "analyst", "viewer"} & user_roles != set()
}

# HR dashboard - restricted
allow if {
    input.action == "view"
    input.resource == "dashboard.hr"
    {"hr_manager", "executive"} & user_roles != set()
}

# Data export rules
allow if {
    input.action == "export"
    {"data_engineer", "analyst", "executive"} & user_roles != set()
    not contains_pii(input.resource)
}
```

---

# Dashboard Access Matrix

| Dashboard | Admin | Analyst | Viewer | Executive | Sales | HR | Ops |
|-----------|-------|---------|--------|-----------|-------|----|----|
| 💰 Sales | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| 👔 HR | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| ⚙️ Operations | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| 👥 Customer | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| 📦 Inventory | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| 🤖 AI Assistant | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |

---

# Part 6: Live Demo & Operations
## (10 minutes)

---

# Starting the Stack

```bash
# One command to start everything
./start.sh

# What happens:
# Step 1: PostgreSQL (port 5432)
# Step 2: Streamlit (port 8501)
# Step 3: dbt-docs (port 8080)
# Step 4: SQL Server (port 1433)
# Step 5: AdventureWorks installation
# Step 6: Airbyte (port 8000)
# Step 7: OPAL/OPA (port 8181)
```

---

# Service URLs

```
┌────────────────────────────────────────────────────────────┐
│                     Service Dashboard                       │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  📊 PostgreSQL        localhost:5432      [postgres/postgres]
│  📈 Streamlit         http://localhost:8501                │
│  📚 dbt Docs          http://localhost:8080                │
│  🗄️ SQL Server        localhost:1433      [sa/YourStrong@] │
│  🔄 Airbyte           http://localhost:8000                │
│  🔐 OPA               http://localhost:8181                │
│  🔐 OPAL Server       http://localhost:7002                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

# Useful Commands

```bash
# View all containers
docker-compose ps

# View logs
docker-compose logs -f streamlit
docker-compose logs -f dbt-docs

# Run dbt commands
cd dbt
./run_dbt.sh run        # Run all models
./run_dbt.sh test       # Run tests
./run_dbt.sh build      # Run + test

# Airbyte
abctl local status      # Check status
abctl local credentials # Get credentials

# OPAL
cd opal
./setup.sh status       # Check status
./setup.sh test         # Test policies

# Stop everything
./stop.sh
```

---

# Demo Flow

### 1. Data Pipeline
- View AdventureWorks in SQL Server
- Show Airbyte sync job
- Explore raw data in PostgreSQL

### 2. dbt Transformation
- Run dbt models
- View lineage graph in dbt Docs
- Explore mart tables

### 3. Analytics
- Navigate Streamlit dashboards
- Ask AI Assistant questions
- Show visualizations

### 4. Authorization
- Switch user profiles
- See access restrictions
- Test policy decisions

---

# Part 7: Q&A and Next Steps
## (5 minutes)

---

# Key Takeaways

### 1. Modern Data Stack
- Modular, best-of-breed components
- ELT > ETL (transform in warehouse)
- SQL-based transformations

### 2. Data Pipeline
- Airbyte for ingestion (300+ connectors)
- dbt for transformation (staging → marts)
- PostgreSQL for storage

### 3. Analytics
- Streamlit for dashboards
- AI Assistant for NL queries
- Auto-sync between dbt and AI

### 4. Security
- OPA/OPAL for authorization
- Policy-as-code
- Role-based access control

---

# Best Practices

| Area | Best Practice |
|------|---------------|
| **dbt** | Use staging → intermediate → marts pattern |
| **dbt** | Document all models with descriptions |
| **dbt** | Add tests for data quality |
| **AI** | Always validate generated SQL |
| **AI** | Keep schema context up to date |
| **Security** | Default deny, least privilege |
| **Security** | Keep policies in version control |
| **Ops** | Use Docker Compose for consistency |
| **Ops** | Monitor container health |

---

# Next Steps

### Immediate
- [ ] Deploy to your environment
- [ ] Connect your data sources
- [ ] Customize dashboards for your use cases

### Short-term
- [ ] Add more dbt models for your data
- [ ] Create custom AI prompts
- [ ] Define role-based access policies

### Long-term
- [ ] Scale to production (Kubernetes)
- [ ] Add more data sources
- [ ] Implement data quality monitoring
- [ ] Set up CI/CD for dbt models

---

# Resources

### Documentation
- `/README.md` - Project overview
- `/dbt/README.md` - dbt project guide
- `/streamlit/README.md` - Dashboard guide
- `/opal/README.md` - Security setup

### External
- [dbt Documentation](https://docs.getdbt.com/)
- [Airbyte Documentation](https://docs.airbyte.com/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Streamlit Documentation](https://docs.streamlit.io/)

### Try It
```bash
git clone <repo>
cd data_warehouse
./start.sh
# Open http://localhost:8501
```

---

# Thank You!

## 📊 Data-Driven Decisions Made Easy

### Questions?

---

# Appendix A: Project Structure

```
data_warehouse/
├── docker-compose.yml       # Core services
├── start.sh                 # Start everything
├── launch.sh                # Launch analytics
├── stop.sh                  # Stop everything
│
├── adventureworks/          # Sample data source
├── airbyte/                 # Data ingestion setup
│
├── dbt/                     # Data transformation
│   ├── models/
│   │   ├── staging/         # 88 staging models
│   │   ├── intermediate/    # dims + facts
│   │   └── marts/           # 5 analytics marts
│   └── scripts/
│
├── streamlit/               # Analytics dashboard
│   ├── app.py               # Main application
│   ├── pages/               # Multi-page modules
│   └── ai/                  # AI Assistant
│
└── opal/                    # Access control
    ├── policies/            # Rego files
    └── data/                # Users, roles
```

---

# Appendix B: dbt Commands

```bash
# Setup
./setup_venv.sh              # Create virtual environment
./setup_schema.sh            # Create database schema

# Running models
./run_dbt.sh run             # Run all models
./run_dbt.sh run -s marts    # Run only marts
./run_dbt.sh run -s +mart_sales  # Run mart_sales and dependencies

# Testing
./run_dbt.sh test            # Run all tests
./run_dbt.sh test -s marts   # Test only marts

# Documentation
./run_dbt.sh docs generate   # Generate docs
./run_dbt.sh docs serve      # Serve locally

# Debugging
./run_dbt.sh debug           # Check connection
./run_dbt.sh compile         # Compile SQL without running
```

---

# Appendix C: Environment Variables

```bash
# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=data_warehouse
POSTGRES_PORT=5432

# SQL Server
SQLSERVER_SA_PASSWORD=YourStrong@Passw0rd
SQLSERVER_PORT=1433

# Service Ports
STREAMLIT_PORT=8501
DBT_DOCS_PORT=8080

# AI (set in streamlit/.env)
OPENAI_API_KEY=sk-proj-xxx
OPENAI_MODEL=gpt-4o

# OPAL
OPAL_ENABLED=true
OPA_URL=http://localhost:8181
```
