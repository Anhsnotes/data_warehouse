#!/bin/bash
# OPA Access Control Setup Script
# 
# Two deployment modes:
# - Standalone OPA (default): Works immediately with local policies
# - Full OPAL stack: Requires Git repository for policies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       OPA Access Control for Data Warehouse               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Get compose command
get_compose_cmd() {
    if docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# Create .env file if not present
create_env() {
    if [ ! -f ".env" ]; then
        cat > .env << 'EOF'
# OPA Access Control Configuration

# OPA Settings
OPA_PORT=8181
OPA_LOG_LEVEL=info

# OPAL Settings (for Git-based policy management)
# Uncomment and configure to enable OPAL:
# OPAL_POLICY_REPO_URL=https://github.com/your-org/policies.git
# OPAL_POLICY_REPO_BRANCH=main
# OPAL_SERVER_PORT=7002
# OPAL_CLIENT_PORT=7001
# OPAL_OPA_PORT=8183
# OPAL_LOG_LEVEL=INFO
EOF
        echo -e "${GREEN}Created .env configuration file${NC}"
    fi
}

# Networks are managed by docker-compose
create_networks() {
    # Networks created automatically by docker-compose
    true
}

# Function to start standalone OPA
start_standalone() {
    echo -e "${YELLOW}Starting standalone OPA...${NC}"
    echo
    
    create_networks
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD up -d opa
    
    echo
    echo -e "${GREEN}OPA Access Control started!${NC}"
    echo
    echo -e "${BLUE}Service URL:${NC}"
    echo -e "  • OPA Server: http://localhost:${OPA_PORT:-8181}"
    echo
    echo -e "${BLUE}Architecture:${NC}"
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │             Standalone OPA              │"
    echo "  │                                         │"
    echo "  │  ┌─────────────┐    ┌─────────────┐   │"
    echo "  │  │   Rego      │    │    JSON     │   │"
    echo "  │  │  Policies   │    │    Data     │   │"
    echo "  │  └──────┬──────┘    └──────┬──────┘   │"
    echo "  │         └──────────┬───────┘         │"
    echo "  │              ┌─────▼─────┐            │"
    echo "  │              │   OPA     │            │"
    echo "  │              │  :8181    │            │"
    echo "  │              └───────────┘            │"
    echo "  └─────────────────────────────────────────┘"
    echo
    echo -e "${YELLOW}To upgrade to Git-based policies later:${NC}"
    echo "  1. Configure OPAL_POLICY_REPO_URL in .env"
    echo "  2. Run: ./setup.sh start-opal"
}

# Function to start full OPAL stack
start_opal() {
    echo -e "${YELLOW}Starting OPAL + OPA stack...${NC}"
    
    # Check if Git repo is configured
    if [ -z "${OPAL_POLICY_REPO_URL}" ]; then
        echo -e "${RED}Error: OPAL_POLICY_REPO_URL is not configured${NC}"
        echo
        echo "To use OPAL with this repo's policies:"
        echo "  1. Push this repo to GitHub/GitLab"
        echo "  2. Configure opal/.env:"
        echo "     cp opal/env.example opal/.env"
        echo "     # Edit .env and set:"
        echo "     OPAL_POLICY_REPO_URL=https://github.com/YOUR_USERNAME/data_warehouse.git"
        echo "     OPAL_REPO_POLICY_PATHS=opal/policies"
        echo "  3. Run: ./setup.sh start-opal"
        echo
        echo "Or use standalone OPA for local policies (no Git needed):"
        echo "  ./setup.sh start"
        exit 1
    fi
    
    echo -e "${BLUE}Policy source: ${OPAL_POLICY_REPO_URL}${NC}"
    echo -e "${BLUE}Policy path:   ${OPAL_REPO_POLICY_PATHS:-opal/policies}${NC}"
    
    create_networks
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile opal up -d
    
    echo
    echo -e "${GREEN}OPAL + OPA stack started!${NC}"
    echo
    echo -e "${BLUE}Service URLs:${NC}"
    echo -e "  • OPAL Server:   http://localhost:${OPAL_SERVER_PORT:-7002}"
    echo -e "  • OPAL Client:   http://localhost:${OPAL_CLIENT_PORT:-7001}"
    echo -e "  • OPA (OPAL):    http://localhost:${OPAL_OPA_PORT:-8183}"
    echo -e "  • OPA (standalone): http://localhost:${OPA_PORT:-8181}"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping OPA services...${NC}"
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile opal down
    
    echo -e "${GREEN}All services stopped${NC}"
}

# Function to test policy evaluation
test_policy() {
    echo -e "${YELLOW}Testing policy evaluation...${NC}"
    
    OPA_URL="http://localhost:${OPA_PORT:-8181}"
    
    # Wait for OPA to be ready
    echo "Waiting for OPA to be ready..."
    for i in {1..30}; do
        if curl -s "$OPA_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}OPA is ready!${NC}"
            break
        fi
        sleep 1
    done
    
    if ! curl -s "$OPA_URL/health" > /dev/null 2>&1; then
        echo -e "${RED}OPA is not responding. Is it running?${NC}"
        echo "Try: ./setup.sh start"
        exit 1
    fi
    
    echo
    echo -e "${BLUE}Test 1: Admin user accessing any resource${NC}"
    echo "  Input: user=admin@company.com, action=read, resource=mart_sales"
    RESULT=$(curl -s -X POST "$OPA_URL/v1/data/datawarehouse/authz/allow" \
        -H "Content-Type: application/json" \
        -d '{"input": {"user": "admin@company.com", "action": "read", "resource": "mart_sales"}}')
    echo "  Result: $RESULT"
    if echo "$RESULT" | grep -q '"result":true'; then
        echo -e "  ${GREEN}✓ PASSED (access allowed)${NC}"
    else
        echo -e "  ${RED}✗ FAILED${NC}"
    fi
    
    echo
    echo -e "${BLUE}Test 2: Analyst accessing mart table${NC}"
    echo "  Input: user=senior.analyst@company.com, action=read, resource=mart_sales"
    RESULT=$(curl -s -X POST "$OPA_URL/v1/data/datawarehouse/authz/allow" \
        -H "Content-Type: application/json" \
        -d '{"input": {"user": "senior.analyst@company.com", "action": "read", "resource": "mart_sales"}}')
    echo "  Result: $RESULT"
    if echo "$RESULT" | grep -q '"result":true'; then
        echo -e "  ${GREEN}✓ PASSED (access allowed)${NC}"
    else
        echo -e "  ${RED}✗ FAILED${NC}"
    fi
    
    echo
    echo -e "${BLUE}Test 3: Viewer trying to export data (should be denied)${NC}"
    echo "  Input: user=junior.analyst@company.com, action=export, resource=mart_sales"
    RESULT=$(curl -s -X POST "$OPA_URL/v1/data/datawarehouse/authz/allow" \
        -H "Content-Type: application/json" \
        -d '{"input": {"user": "junior.analyst@company.com", "action": "export", "resource": "mart_sales"}}')
    echo "  Result: $RESULT"
    if echo "$RESULT" | grep -q '"result":false'; then
        echo -e "  ${GREEN}✓ PASSED (access denied as expected)${NC}"
    else
        echo -e "  ${RED}✗ FAILED${NC}"
    fi
    
    echo
    echo -e "${BLUE}Test 4: Sales manager accessing sales dashboard${NC}"
    echo "  Input: user=sales.manager.west@company.com, action=view, resource=dashboard.sales"
    RESULT=$(curl -s -X POST "$OPA_URL/v1/data/datawarehouse/authz/allow" \
        -H "Content-Type: application/json" \
        -d '{"input": {"user": "sales.manager.west@company.com", "action": "view", "resource": "dashboard.sales"}}')
    echo "  Result: $RESULT"
    if echo "$RESULT" | grep -q '"result":true'; then
        echo -e "  ${GREEN}✓ PASSED (access allowed)${NC}"
    else
        echo -e "  ${RED}✗ FAILED${NC}"
    fi
    
    echo
    echo -e "${GREEN}Policy tests completed!${NC}"
}

# Function to show logs
show_logs() {
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile opal logs -f
}

# Function to show status
show_status() {
    echo -e "${BLUE}OPA Access Control Status:${NC}"
    echo
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile opal ps
    
    echo
    echo -e "${BLUE}Health Checks:${NC}"
    
    # Check standalone OPA
    if curl -s "http://localhost:${OPA_PORT:-8181}/health" > /dev/null 2>&1; then
        echo -e "  OPA (standalone): ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  OPA (standalone): ${RED}✗ Not responding${NC}"
    fi
    
    # Check OPAL Server
    if curl -s "http://localhost:${OPAL_SERVER_PORT:-7002}/healthcheck" > /dev/null 2>&1; then
        echo -e "  OPAL Server:      ${GREEN}✓ Healthy${NC}"
    fi
    
    # Check OPAL Client
    if curl -s "http://localhost:${OPAL_CLIENT_PORT:-7001}/healthcheck" > /dev/null 2>&1; then
        echo -e "  OPAL Client:      ${GREEN}✓ Healthy${NC}"
    fi
    
    # Check OPAL OPA
    if curl -s "http://localhost:${OPAL_OPA_PORT:-8183}/health" > /dev/null 2>&1; then
        echo -e "  OPA (via OPAL):   ${GREEN}✓ Healthy${NC}"
    fi
}

# Function to reload policies (for standalone OPA)
reload_policies() {
    echo -e "${YELLOW}Reloading policies...${NC}"
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD restart opa
    
    echo -e "${GREEN}Policies reloaded!${NC}"
}

# Main command handling
case "${1:-}" in
    start)
        create_env
        start_standalone
        ;;
    start-opal)
        create_env
        source .env 2>/dev/null || true
        start_opal
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        create_env
        start_standalone
        ;;
    test)
        test_policy
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    reload)
        reload_policies
        ;;
    *)
        echo "Usage: $0 {start|start-opal|stop|restart|test|logs|status|reload}"
        echo
        echo "Commands:"
        echo "  start       Start standalone OPA (default, works with local policies)"
        echo "  start-opal  Start full OPAL stack (requires Git repo configuration)"
        echo "  stop        Stop all services"
        echo "  restart     Restart services"
        echo "  test        Run policy evaluation tests"
        echo "  logs        Show service logs"
        echo "  status      Show service status"
        echo "  reload      Reload policies (restart OPA)"
        echo
        echo "Deployment Modes:"
        echo
        echo "  STANDALONE (default):"
        echo "    - OPA loads policies from local ./policies directory"
        echo "    - Ready for production use immediately"
        echo "    - Policies updated by editing files + ./setup.sh reload"
        echo
        echo "  OPAL (optional):"
        echo "    - OPAL Server tracks Git repository for policies"
        echo "    - Automatic policy updates on Git push"
        echo "    - Requires OPAL_POLICY_REPO_URL in .env"
        echo
        exit 1
        ;;
esac
