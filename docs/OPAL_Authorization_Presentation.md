# OPAL Authorization in Data Warehouse
## A Comprehensive 1-Hour Workshop

---

# Agenda (60 minutes)

| Time | Topic |
|------|-------|
| 0:00 - 0:05 | Introduction & Overview |
| 0:05 - 0:15 | Architecture Deep Dive |
| 0:15 - 0:25 | OPAL & OPA Fundamentals |
| 0:25 - 0:35 | Policy Design & Implementation |
| 0:35 - 0:45 | Live Demo & Code Walkthrough |
| 0:45 - 0:55 | Hands-on Exercise |
| 0:55 - 1:00 | Q&A and Wrap-up |

---

# Part 1: Introduction & Overview
## (5 minutes)

---

# What We're Building

A **modern data warehouse** with enterprise-grade authorization

```
┌─────────────────────────────────────────────────────────────┐
│                    Streamlit Dashboard                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│  │  Sales  │ │   HR    │ │   Ops   │ │   AI    │           │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘           │
│       │           │           │           │                  │
│       └───────────┴───────────┴───────────┘                  │
│                         │                                    │
│                    ┌────▼────┐                               │
│                    │  OPAL   │  ◄── Policy-based Access     │
│                    └────┬────┘                               │
│                         │                                    │
└─────────────────────────┼───────────────────────────────────┘
                          │
                    ┌─────▼─────┐
                    │ PostgreSQL │
                    │ (dbt marts)│
                    └───────────┘
```

---

# Project Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Data Pipeline** | dbt + PostgreSQL | Transform raw data into analytics marts |
| **Visualization** | Streamlit | Interactive dashboards |
| **Authorization** | OPAL + OPA | Fine-grained access control |
| **AI Assistant** | OpenAI/Anthropic | Natural language queries |
| **Data Source** | AdventureWorks | Sample enterprise data |

---

# Why Authorization Matters

### The Problem
- Different users need different data access levels
- Compliance requirements (GDPR, SOC2, HIPAA)
- Prevent data breaches and unauthorized access
- Audit trail requirements

### The Solution
- **Centralized policy management**
- **Real-time policy updates**
- **Declarative, auditable policies**
- **Separation of policy from code**

---

# Part 2: Architecture Deep Dive
## (10 minutes)

---

# System Architecture

```
                                    ┌─────────────────────┐
                                    │   Policy Repository │
                                    │   (Git/File System) │
                                    └──────────┬──────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │    OPAL Server      │
                                    │  (Policy Admin)     │
                                    └──────────┬──────────┘
                                               │
        ┌──────────────────────────────────────┼──────────────────────────────────────┐
        │                                      │                                       │
        ▼                                      ▼                                       ▼
┌───────────────┐                    ┌─────────────────┐                    ┌───────────────┐
│  OPAL Client  │                    │   OPAL Client   │                    │  OPAL Client  │
│   + OPA #1    │                    │    + OPA #2     │                    │   + OPA #3    │
└───────┬───────┘                    └────────┬────────┘                    └───────┬───────┘
        │                                     │                                     │
        ▼                                     ▼                                     ▼
┌───────────────┐                    ┌─────────────────┐                    ┌───────────────┐
│  Streamlit    │                    │   API Service   │                    │  ETL Pipeline │
│  Dashboard    │                    │                 │                    │               │
└───────────────┘                    └─────────────────┘                    └───────────────┘
```

---

# Authorization Flow

```
┌─────────┐    1. Request      ┌─────────────┐
│  User   │ ─────────────────► │  Streamlit  │
└─────────┘                    │  Dashboard  │
                               └──────┬──────┘
                                      │
                               2. Auth Check
                                      │
                                      ▼
                               ┌─────────────┐
                               │    OPA      │
                               │  (Policy    │
                               │  Decision)  │
                               └──────┬──────┘
                                      │
                               3. Allow/Deny
                                      │
                                      ▼
                               ┌─────────────┐
                               │   Return    │
                               │   Result    │
                               └─────────────┘
```

---

# Data Flow in dbt

```
┌─────────────────────────────────────────────────────────────────────┐
│                          dbt Transformation Layers                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐      ┌──────────────┐      ┌─────────────────┐       │
│  │ Staging  │ ───► │ Intermediate │ ───► │     Marts       │       │
│  │          │      │              │      │                 │       │
│  │ stg_*    │      │ dim_*        │      │ mart_sales      │       │
│  │          │      │ fact_*       │      │ mart_customer   │       │
│  │          │      │              │      │ mart_operations │       │
│  └──────────┘      └──────────────┘      └─────────────────┘       │
│                                                   │                  │
│                                                   ▼                  │
│                                          ┌─────────────────┐        │
│                                          │   Streamlit     │        │
│                                          │   Dashboard     │        │
│                                          └─────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

---

# Part 3: OPAL & OPA Fundamentals
## (10 minutes)

---

# What is OPA?

**Open Policy Agent** - A general-purpose policy engine

### Key Features
- 🔓 **Decoupled** - Separates policy from application code
- 📝 **Declarative** - Policies written in Rego language
- ⚡ **Fast** - Sub-millisecond policy evaluation
- 🔌 **Universal** - Works with any application

### Use Cases
- Kubernetes admission control
- API authorization
- Data filtering
- Feature flags

---

# What is OPAL?

**Open Policy Administration Layer** - Policy distribution & data synchronization

```
┌─────────────────────────────────────────────────────────────┐
│                        OPAL Server                           │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ Policy Watcher  │    │  Data Publisher │                 │
│  │ (Git/Webhook)   │    │  (REST/Kafka)   │                 │
│  └────────┬────────┘    └────────┬────────┘                 │
│           │                      │                           │
│           └──────────┬───────────┘                          │
│                      │                                       │
│              ┌───────▼───────┐                              │
│              │  WebSocket    │                              │
│              │  Pub/Sub      │                              │
│              └───────┬───────┘                              │
└──────────────────────┼──────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ Client  │   │ Client  │   │ Client  │
    │ + OPA   │   │ + OPA   │   │ + OPA   │
    └─────────┘   └─────────┘   └─────────┘
```

---

# The Rego Language

```rego
# Package declaration
package datawarehouse.authz

# Default deny - secure by default
default allow := false

# Rule: Allow if user has matching permission
allow if {
    some role in user_roles
    some permission in data.roles[role].permissions
    permission_matches(permission, input.action, input.resource)
}

# Helper: Check permission match
permission_matches(permission, action, resource) if {
    permission.action == action
    permission.resource == resource
}
```

---

# Rego Key Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **Rules** | Boolean expressions | `allow if { ... }` |
| **Input** | Request data | `input.user`, `input.action` |
| **Data** | External data | `data.roles`, `data.users` |
| **Sets** | Unique collections | `user_roles contains role` |
| **Iteration** | Loop over data | `some role in roles` |

---

# Part 4: Policy Design & Implementation
## (10 minutes)

---

# User & Role Model

```json
// users.json
{
  "users": {
    "admin@company.com": {
      "name": "System Administrator",
      "roles": ["admin"]
    },
    "senior.analyst@company.com": {
      "name": "Senior Data Analyst",
      "roles": ["analyst"]
    },
    "junior.analyst@company.com": {
      "name": "Junior Data Analyst",
      "roles": ["viewer"]
    },
    "sales.manager.west@company.com": {
      "name": "Sales Manager - West",
      "roles": ["sales_manager"],
      "territories": ["1", "2", "3"]
    }
  }
}
```

---

# Role Permissions

```json
// roles.json
{
  "roles": {
    "admin": {
      "permissions": [{"action": "*", "resource": "*"}]
    },
    "analyst": {
      "permissions": [
        {"action": "read", "resource": "mart_*"},
        {"action": "view", "resource": "dashboard.sales"},
        {"action": "view", "resource": "dashboard.operations"},
        {"action": "view", "resource": "dashboard.ai_assistant"},
        {"action": "export", "resource": "mart_*"}
      ]
    },
    "viewer": {
      "permissions": [
        {"action": "read", "resource": "mart_*"},
        {"action": "view", "resource": "dashboard.sales"},
        {"action": "view", "resource": "dashboard.operations"}
      ]
    }
  }
}
```

---

# Dashboard Access Matrix

| Dashboard | Admin | Engineer | Analyst | Viewer | Executive | Sales Mgr | HR Mgr | Ops Mgr | Marketing |
|-----------|-------|----------|---------|--------|-----------|-----------|--------|---------|-----------|
| Sales | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| HR | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Operations | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| Customer | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ |
| Inventory | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |
| AI Assistant | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |

---

# Policy Implementation: RBAC

```rego
# rbac.rego - Role-Based Access Control

package datawarehouse.authz

import future.keywords.if
import future.keywords.in
import future.keywords.contains

default allow := false

# Get user roles from data
user_roles contains role if {
    some role in data.users[input.user].roles
}

# Admin has full access
allow if {
    "admin" in user_roles
}

# Check against role permissions
allow if {
    some role in user_roles
    some permission in data.roles[role].permissions
    permission_matches(permission, input.action, input.resource)
}
```

---

# Policy Implementation: Dashboard Rules

```rego
# Dashboard-specific access rules

# Sales dashboard - multiple roles allowed
allow if {
    input.action == "view"
    input.resource == "dashboard.sales"
    {"sales_manager", "executive", "analyst", "viewer"} & user_roles != set()
}

# HR dashboard - restricted access
allow if {
    input.action == "view"
    input.resource == "dashboard.hr"
    {"hr_manager", "executive"} & user_roles != set()
}

# AI Assistant - power users only
allow if {
    input.action == "view"
    input.resource == "dashboard.ai_assistant"
    {"analyst", "data_engineer", "executive"} & user_roles != set()
}
```

---

# Advanced: Row-Level Security

```rego
# data_access.rego - Row-Level Security

# Generate SQL filter for territory-scoped access
row_filter_condition := filter if {
    "sales_manager" in input.user_roles
    input.table == "mart_sales"
    user := data.users[input.user]
    territories := user.territories
    filter := sprintf("territory_id IN (%s)", 
                      [concat(", ", territories)])
}

# No filter for full-access roles
row_filter_condition := "1=1" if {
    {"admin", "data_engineer"} & input.user_roles != set()
}
```

---

# Part 5: Live Demo & Code Walkthrough
## (10 minutes)

---

# Demo: OPAL Authorization Page

### What We'll See:
1. **Profile Switching** - Different users see different access
2. **Dashboard Cards** - Visual access/denied indicators
3. **Export Permissions** - Data export restrictions
4. **Permissions Matrix** - Full access overview

### Key Observations:
- Junior Analyst can't access HR, Customer Analytics, AI
- Sales Manager can't see HR or Operations dashboards
- HR Director only sees HR dashboard
- Admin sees everything

---

# Code Walkthrough: OPAL Client

```python
# opal_demo.py - OPAL Client

class OPALClient:
    def __init__(self, opa_url=None):
        self.opa_url = opa_url or 'http://localhost:8181'
    
    def authorize(self, user: str, action: str, resource: str) -> bool:
        """Check authorization via OPA."""
        response = httpx.post(
            f"{self.opa_url}/v1/data/datawarehouse/authz/allow",
            json={
                "input": {
                    "user": user,
                    "action": action,
                    "resource": resource
                }
            }
        )
        return response.json().get("result", False)
```

---

# Code Walkthrough: Permission Check

```python
def check_permission(user_email, action, resource, opal_client=None):
    """
    Check if user has permission.
    Uses OPAL/OPA if available, falls back to local policy.
    """
    # Try OPAL first
    if opal_client:
        result = opal_client.authorize(user_email, action, resource)
        if result is not None:
            return result
    
    # Fallback to local policy check
    user = USERS.get(user_email)
    user_roles = set(user.get("roles", []))
    
    # Admin has full access
    if "admin" in user_roles:
        return True
    
    # Check dashboard permissions
    if action == "view" and resource in DASHBOARD_PERMISSIONS:
        allowed_roles = set(DASHBOARD_PERMISSIONS[resource]["allowed_roles"])
        return bool(user_roles & allowed_roles)
    
    return False
```

---

# Code Walkthrough: UI Rendering

```python
def render_dashboard_card(dashboard_id, dashboard_info, allowed, conn):
    """Render a dashboard card with access status."""
    
    if allowed:
        # Green border, full content, data preview
        st.markdown(f"""
        <div style="border-left: 4px solid #10b981; ...">
            <h3>{dashboard_info['title']}</h3>
            <span>ACCESSIBLE</span>
        </div>
        """, unsafe_allow_html=True)
        
        # Show sample data
        render_sample_data(dashboard_id, conn)
    else:
        # Red border, blurred content, lock icon
        st.markdown(f"""
        <div style="border-left: 4px solid #ef4444; opacity: 0.7; ...">
            <div style="filter: blur(2px);">
                <h3>{dashboard_info['title']}</h3>
            </div>
            <span>🔒 ACCESS DENIED</span>
        </div>
        """, unsafe_allow_html=True)
```

---

# Part 6: Hands-on Exercise
## (10 minutes)

---

# Exercise 1: Add a New Role

**Task:** Create a "finance_analyst" role that can:
- View Sales and Customer Analytics dashboards
- Export sales data only
- Cannot access HR or Operations

**Steps:**
1. Add role to `opal/data/roles.json`
2. Add user to `opal/data/users.json`
3. Update `streamlit/pages/opal_demo.py`
4. Test the new role

---

# Exercise 1: Solution

```json
// roles.json - Add new role
"finance_analyst": {
  "description": "Finance team analyst",
  "permissions": [
    {"action": "read", "resource": "mart_sales"},
    {"action": "read", "resource": "mart_customer_analytics"},
    {"action": "view", "resource": "dashboard.sales"},
    {"action": "view", "resource": "dashboard.customer_analytics"},
    {"action": "export", "resource": "mart_sales"}
  ]
}
```

```json
// users.json - Add new user
"finance.analyst@company.com": {
  "name": "Finance Analyst",
  "roles": ["finance_analyst"],
  "active": true
}
```

---

# Exercise 2: Add Row-Level Security

**Task:** Implement territory-based filtering for sales managers

**Scenario:**
- West Region Manager: Only sees territories 1, 2, 3
- East Region Manager: Only sees territories 4, 5, 6

**Hint:** Use the `row_filter_condition` rule in `data_access.rego`

---

# Exercise 2: Solution

```rego
# data_access.rego

row_filter_condition := filter if {
    "sales_manager" in input.user_roles
    input.table == "mart_sales"
    
    # Get user's assigned territories
    user := data.users[input.user]
    territories := user.territories
    
    # Build SQL WHERE clause
    territory_list := concat(", ", territories)
    filter := sprintf("territory_id IN (%s)", [territory_list])
}
```

```python
# In Python application
filter_sql = opal_client.get_row_filter(user, "mart_sales")
if filter_sql:
    query = f"SELECT * FROM mart_sales WHERE {filter_sql}"
```

---

# Part 7: Q&A and Wrap-up
## (5 minutes)

---

# Key Takeaways

1. **Separation of Concerns**
   - Policy logic is separate from application code
   - Easier to audit, test, and modify

2. **Declarative Policies**
   - Rego is expressive and readable
   - Policies as code = version controlled

3. **Real-time Updates**
   - OPAL pushes policy changes instantly
   - No application restart needed

4. **Defense in Depth**
   - UI restrictions + server-side enforcement
   - Row-level security for sensitive data

---

# Best Practices

| Practice | Description |
|----------|-------------|
| **Default Deny** | Start with `default allow := false` |
| **Least Privilege** | Only grant necessary permissions |
| **Audit Logging** | Track all authorization decisions |
| **Test Policies** | Use OPA's built-in testing framework |
| **Version Control** | Keep policies in Git |
| **Fail Closed** | Deny access on errors |

---

# Resources & Next Steps

### Documentation
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [OPAL GitHub](https://github.com/permitio/opal)
- [Rego Playground](https://play.openpolicyagent.org/)

### Project Files
- `opal/policies/rbac.rego` - Main authorization policy
- `opal/policies/data_access.rego` - Row-level security
- `opal/data/*.json` - Users, roles, permissions
- `streamlit/pages/opal_demo.py` - Demo implementation

### Try It Yourself
```bash
cd data_warehouse
./start.sh           # Start all services
# Navigate to http://localhost:8501
# Select "OPAL Authorization Demo"
```

---

# Questions?

### Contact & Resources

📧 Email: team@company.com
📚 Docs: `/docs/OPAL_Authorization_Presentation.md`
💻 Code: `/opal/` and `/streamlit/pages/opal_demo.py`

---

# Thank You!

## 🛡️ Secure Data, Happy Users

---

# Appendix A: Docker Setup

```yaml
# docker-compose.yml (OPAL section)
services:
  opal-server:
    image: permitio/opal-server:latest
    environment:
      - OPAL_POLICY_REPO_URL=https://github.com/your-repo
      - OPAL_DATA_CONFIG_SOURCES={"config":{...}}
    ports:
      - "7002:7002"

  opal-client:
    image: permitio/opal-client:latest
    environment:
      - OPAL_SERVER_URL=http://opal-server:7002
    ports:
      - "8181:8181"  # OPA port
```

---

# Appendix B: Testing Policies

```rego
# rbac_test.rego

package datawarehouse.authz_test

import data.datawarehouse.authz

# Test admin access
test_admin_allows_everything {
    authz.allow with input as {
        "user": "admin@company.com",
        "action": "view",
        "resource": "dashboard.hr"
    }
}

# Test viewer restrictions
test_viewer_denied_hr {
    not authz.allow with input as {
        "user": "junior.analyst@company.com",
        "action": "view",
        "resource": "dashboard.hr"
    }
}
```

Run tests: `opa test ./policies -v`

---

# Appendix C: API Integration

```python
# Example: Protecting an API endpoint

from functools import wraps
from flask import request, jsonify

def require_permission(action, resource):
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            user = get_current_user()
            
            if not opal_client.authorize(user, action, resource):
                return jsonify({
                    "error": "Access denied",
                    "required_permission": f"{action}:{resource}"
                }), 403
            
            return f(*args, **kwargs)
        return wrapped
    return decorator

@app.route("/api/sales")
@require_permission("read", "mart_sales")
def get_sales():
    return jsonify(fetch_sales_data())
```
