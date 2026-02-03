# OPA Access Control for Data Warehouse

Production-ready access control using **OPA** (Open Policy Agent) with optional **OPAL** (Open Policy Administration Layer) for Git-based policy management.

## Architecture

### Mode 1: Standalone OPA (Default)

Simple deployment with policies loaded from local files. **No external dependencies.**

```
┌─────────────────────────────────────┐
│         Standalone OPA              │
│                                     │
│  ┌─────────────┐  ┌─────────────┐  │
│  │    Rego     │  │    JSON     │  │
│  │  Policies   │  │    Data     │  │
│  │ (policies/) │  │   (data/)   │  │
│  └──────┬──────┘  └──────┬──────┘  │
│         └────────┬───────┘         │
│            ┌─────▼─────┐           │
│            │    OPA    │           │
│            │   :8181   │           │
│            └───────────┘           │
└─────────────────────────────────────┘
```

### Mode 2: OPAL + OPA (Git-based)

Full stack with real-time policy sync from Git. **Use when you need:**
- Automatic policy updates when Git changes
- Multi-instance deployments
- Audit trail of policy changes

```
┌─────────────────────────────────────────────────────────────────┐
│                      OPAL + OPA Stack                           │
│                                                                 │
│  ┌──────────┐    ┌─────────────┐    ┌──────────────────────┐   │
│  │ Broadcast│◄──►│ OPAL Server │◄──►│    OPAL Client       │   │
│  │ Channel  │    │   :7002     │    │      :7001           │   │
│  │ (Postgres)    │             │    │  ┌────────────────┐  │   │
│  └──────────┘    │  Git Sync   │    │  │  Embedded OPA  │  │   │
│                  └──────┬──────┘    │  │     :8183      │  │   │
│                         │           │  └────────────────┘  │   │
│                  ┌──────▼──────┐    └──────────────────────┘   │
│                  │  Git Repo   │                               │
│                  │ (policies)  │                               │
│                  └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Option A: Standalone OPA

```bash
cd opal
./setup.sh start
./setup.sh test
```

**That's it!** OPA is running at http://localhost:8181

### Option B: OPAL + OPA (Git-based policies)

1. **Configure OPAL** (if not already done):
   ```bash
   cd opal
   cp env.example .env
   # Edit .env and set your repo URL:
   # OPAL_POLICY_REPO_URL=https://github.com/YOUR_USERNAME/data_warehouse.git
   ```

2. **Start OPAL stack:**
   ```bash
   ./setup.sh start-opal
   ```

3. **Verify:**
   ```bash
   ./setup.sh status
   ./setup.sh test
   ```

## Service URLs

| Mode | Service | URL | Description |
|------|---------|-----|-------------|
| Standalone | OPA | http://localhost:8181 | Policy evaluation |
| OPAL | OPAL Server | http://localhost:7002 | Policy administration, Git sync |
| OPAL | OPAL Client | http://localhost:7001 | Client health and status |
| OPAL | OPA (embedded) | http://localhost:8183 | Policy evaluation via OPAL |

## Commands Reference

```bash
# Standalone OPA
./setup.sh start          # Start standalone OPA with local policies
./setup.sh stop           # Stop all services
./setup.sh restart        # Restart services

# Full OPAL Stack
./setup.sh start-opal     # Start OPAL + OPA (requires Git repo config)

# Management
./setup.sh status         # Check service health
./setup.sh test           # Run policy tests
./setup.sh logs           # View logs
./setup.sh reload         # Reload policies (standalone mode)
```

## Sample Queries

### Check if user can access a resource

```bash
curl -X POST http://localhost:8181/v1/data/datawarehouse/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": "admin@company.com",
      "action": "read",
      "resource": "mart_sales"
    }
  }'
# Response: {"result": true}
```

### Check table access

```bash
curl -X POST http://localhost:8181/v1/data/datawarehouse/data_access/can_access_table \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": "senior.analyst@company.com",
      "table": "mart_sales"
    }
  }'
```

### Get allowed columns for a user

```bash
curl -X POST http://localhost:8181/v1/data/datawarehouse/data_access/allowed_columns \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": "junior.analyst@company.com",
      "table": "dim_customers"
    }
  }'
```

### Debug: View all loaded data

```bash
curl http://localhost:8181/v1/data
curl http://localhost:8181/v1/policies
```

## Directory Structure

```
opal/
├── policies/                    # Rego policy files
│   ├── rbac.rego               # Role-based access control
│   └── data_access.rego        # Table/column/row-level access
├── data/                        # Authorization data (JSON)
│   ├── roles.json              # Role definitions (11 roles)
│   ├── users.json              # User-role mappings
│   └── table_permissions.json  # Table access per role
├── docker-compose.yml          # Service definitions
├── setup.sh                    # Management script
├── env.example                 # Configuration template
├── client.py                   # Python client library
└── README.md                   # This file
```

## Roles and Permissions

### Available Roles

| Role | Description | Access Level |
|------|-------------|--------------|
| `admin` | System administrator | Full access to everything |
| `data_engineer` | Data engineering team | Full data pipeline access |
| `senior_analyst` | Senior data analyst | Read all marts, dims, facts |
| `analyst` | Data analyst | Read marts and dims |
| `viewer` | Read-only user | Limited mart access |
| `executive` | Executive leadership | All dashboards and reports |
| `sales_manager` | Sales team manager | Sales data (territory-scoped) |
| `hr_manager` | HR manager | Employee data (dept-scoped) |
| `finance_manager` | Finance manager | Financial data |
| `operations_manager` | Operations | Inventory and production |
| `marketing_analyst` | Marketing team | Customer and sales analytics |

### Sample Users

| User | Role |
|------|------|
| `admin@company.com` | admin |
| `senior.analyst@company.com` | senior_analyst |
| `junior.analyst@company.com` | viewer |
| `sales.manager.west@company.com` | sales_manager |
| `hr.director@company.com` | hr_manager |

### Permission Actions

- `read` - Read data from tables
- `write` - Write/update data
- `create` - Create new records
- `delete` - Delete records
- `export` - Export data to files
- `view` - View dashboards
- `query` - Execute queries

## Integration with Streamlit

```python
# In your Streamlit app
import httpx

OPA_URL = "http://localhost:8181"  # or host.docker.internal:8181 from container

def check_authorization(user: str, action: str, resource: str) -> bool:
    response = httpx.post(
        f"{OPA_URL}/v1/data/datawarehouse/authz/allow",
        json={"input": {"user": user, "action": action, "resource": resource}}
    )
    return response.json().get("result", False)

# Usage
if check_authorization("analyst@company.com", "read", "mart_sales"):
    show_data()
else:
    st.error("Access denied")
```

## OPAL Git Configuration

When using OPAL mode, policies are synced from a Git repository. Configure in `opal/.env`:

```bash
# Use this repo (policies in opal/policies/ subdirectory)
OPAL_POLICY_REPO_URL=https://github.com/Anhsnotes/data_warehouse.git
OPAL_REPO_POLICY_PATHS=opal/policies

# Or use a dedicated policy repo
OPAL_POLICY_REPO_URL=https://github.com/your-org/opa-policies.git
OPAL_REPO_POLICY_PATHS=.

# For private repos, add SSH key (base64 encoded)
OPAL_POLICY_REPO_SSH_KEY=<base64-encoded-key>
```

OPAL polls for changes every 30 seconds. Push policy updates to Git and they'll be deployed automatically!

## Production Considerations

### High Availability

For production HA:
1. Run multiple OPAL Clients behind a load balancer
2. Use external PostgreSQL for broadcast channel
3. Configure health checks and auto-restart

### Security

- Use HTTPS for all endpoints
- Configure authentication tokens for OPAL
- Restrict network access to OPA ports
- Audit all policy decisions

### Monitoring

```bash
# Health endpoints
curl http://localhost:8181/health          # OPA health
curl http://localhost:7002/healthcheck     # OPAL Server health
curl http://localhost:7001/healthcheck     # OPAL Client health

# Decision logs (enabled in docker-compose)
docker logs data_warehouse_opa
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
./setup.sh logs

# Check individual containers
docker logs data_warehouse_opa
docker logs data_warehouse_opal_server
docker logs data_warehouse_opal_client
```

### Policy Not Working

```bash
# Test policy directly
./setup.sh test

# Check loaded policies
curl http://localhost:8181/v1/policies

# Check loaded data
curl http://localhost:8181/v1/data/roles
curl http://localhost:8181/v1/data/users
```

### OPAL Not Syncing from Git

```bash
# Check OPAL server logs for Git errors
docker logs data_warehouse_opal_server | grep -i "git\|error\|repo"

# Verify repo URL is accessible
curl -I https://github.com/YOUR_USERNAME/data_warehouse.git

# Check if .env is configured
cat opal/.env | grep OPAL_POLICY_REPO_URL
```

## References

- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPAL Documentation](https://docs.opal.ac/)
- [OPAL GitHub](https://github.com/permitio/opal)
