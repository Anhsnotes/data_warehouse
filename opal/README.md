# OPAL + OPA Access Control for Data Warehouse

Production-ready access control using **OPAL** (Open Policy Administration Layer) and **OPA** (Open Policy Agent) for fine-grained authorization with real-time policy and data synchronization.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OPAL + OPA Production Stack                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────┐   │
│  │   Broadcast     │◄───►│   OPAL Server   │◄───►│    OPAL Client      │   │
│  │   Channel       │     │                 │     │                     │   │
│  │  (PostgreSQL)   │     │  • Policy sync  │     │  • Receives updates │   │
│  │                 │     │  • Data config  │     │  • Manages OPA      │   │
│  │  Port: 5432     │     │  Port: 7002     │     │  Port: 7000         │   │
│  └─────────────────┘     └─────────────────┘     └──────────┬──────────┘   │
│                                                              │              │
│                                                    ┌─────────▼─────────┐   │
│                                                    │   Embedded OPA    │   │
│                                                    │                   │   │
│                                                    │  • Policy engine  │   │
│                                                    │  • Rego policies  │   │
│                                                    │  • Auth queries   │   │
│                                                    │  Port: 8181       │   │
│                                                    └───────────────────┘   │
│                                                              ▲              │
└──────────────────────────────────────────────────────────────┼──────────────┘
                                                               │
                    ┌──────────────────────────────────────────┴───┐
                    │              Your Applications               │
                    │  (Streamlit, APIs, Services)                 │
                    │  POST /v1/data/datawarehouse/authz/allow     │
                    └──────────────────────────────────────────────┘
```

## Components

| Component | Port | Purpose |
|-----------|------|---------|
| **Broadcast Channel** | 5432 (internal) | PostgreSQL for pub/sub between OPAL server and clients |
| **OPAL Server** | 7002 | Policy administration, tracks Git repos, pushes updates |
| **OPAL Client** | 7000 | Receives updates, manages embedded OPA lifecycle |
| **OPA (embedded)** | 8181 | Policy evaluation engine for authorization queries |

## Quick Start

### 1. Start Production Stack

```bash
cd opal
./setup.sh start
```

This starts the full production stack:
- Broadcast Channel (PostgreSQL)
- OPAL Server (policy administration)
- OPAL Client with embedded OPA (policy evaluation)

### 2. Verify Services

```bash
./setup.sh status
```

### 3. Test Policies

```bash
./setup.sh test
```

### 4. Query Authorization

```bash
# Check if user can read mart_sales
curl -X POST http://localhost:8181/v1/data/datawarehouse/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "user": "analyst@company.com",
      "action": "read",
      "resource": "mart_sales"
    }
  }'

# Response: {"result": true}
```

## Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| OPAL Server | http://localhost:7002 | Policy administration API |
| OPAL Client | http://localhost:7000 | Client health and status |
| OPA | http://localhost:8181 | **Authorization queries go here** |

## Directory Structure

```
opal/
├── policies/                    # Rego policy files
│   ├── rbac.rego               # Role-based access control
│   └── data_access.rego        # Table/column/row-level access
├── data/                        # Authorization data
│   ├── roles.json              # Role definitions
│   ├── users.json              # User-role mappings
│   └── table_permissions.json  # Table access per role
├── docker-compose.yml          # Production stack definition
├── setup.sh                    # Management script
└── README.md                   # This file
```

## Roles and Permissions

### Available Roles

| Role | Description | Access Level |
|------|-------------|--------------|
| `admin` | System administrator | Full access |
| `data_engineer` | Data engineering team | Full data pipeline access |
| `analyst` | Data analyst | Read marts, dims, facts |
| `viewer` | Read-only user | Limited mart access |
| `executive` | Executive leadership | All dashboards |
| `sales_manager` | Sales team manager | Sales data (territory-scoped) |
| `hr_manager` | HR manager | Employee data (dept-scoped) |
| `operations_manager` | Operations | Inventory and production |

### Permission Actions

- `read` - Read data from tables
- `write` - Write/update data
- `create` - Create new records
- `delete` - Delete records
- `export` - Export data to files
- `view` - View dashboards
- `query` - Execute queries

## Production Features

### Real-Time Policy Updates

OPAL Server can track a Git repository and push policy changes to all OPA instances automatically:

```yaml
# In docker-compose.yml, configure:
- OPAL_POLICY_REPO_URL=https://github.com/your-org/policies.git
- OPAL_POLICY_REPO_MAIN_BRANCH=main
```

### Real-Time Data Updates

Trigger data updates programmatically:

```bash
./setup.sh update

# Or via API:
curl -X POST http://localhost:7002/data/config \
  -H "Content-Type: application/json" \
  -d '{"entries": [{"url": "http://your-data-source/users", "topics": ["policy_data"]}]}'
```

### High Availability

For production HA:
1. Run multiple OPAL Servers behind a load balancer
2. Use external PostgreSQL for broadcast channel
3. Run multiple OPAL Clients for redundancy

## Integration with Streamlit

```python
# In your Streamlit app
import httpx

def check_authorization(user: str, action: str, resource: str) -> bool:
    response = httpx.post(
        "http://localhost:8181/v1/data/datawarehouse/authz/allow",
        json={"input": {"user": user, "action": action, "resource": resource}}
    )
    return response.json().get("result", False)

# Usage
if check_authorization("analyst@company.com", "read", "mart_sales"):
    show_data()
else:
    st.error("Access denied")
```

## Commands Reference

```bash
# Start full production stack
./setup.sh start

# Start standalone OPA only (development)
./setup.sh start-standalone

# Stop all services
./setup.sh stop

# Restart services
./setup.sh restart

# Run policy tests
./setup.sh test

# View logs
./setup.sh logs

# Check status
./setup.sh status

# Trigger data update
./setup.sh update
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
./setup.sh logs

# Check individual container
docker logs data_warehouse_opal_server
docker logs data_warehouse_opal_client
```

### Policy Not Working

```bash
# Test directly against OPA
curl http://localhost:8181/v1/data

# Check loaded policies
curl http://localhost:8181/v1/policies

# Check loaded data
curl http://localhost:8181/v1/data/roles
curl http://localhost:8181/v1/data/users
```

### OPAL Server Not Responding

```bash
# Check broadcast channel
docker logs data_warehouse_opal_broadcast

# Restart in order
./setup.sh stop
./setup.sh start
```

## Production Checklist

- [ ] Configure Git repository for policies
- [ ] Set up external PostgreSQL for broadcast channel
- [ ] Configure SSL/TLS for all endpoints
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Set up backup for policy data
- [ ] Test failover scenarios
- [ ] Document emergency procedures

## References

- [OPAL Documentation](https://docs.opal.ac/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPAL GitHub](https://github.com/permitio/opal)
