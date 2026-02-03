#!/bin/bash
# OPAL + OPA Access Control Setup Script
# Production-ready policy administration and authorization

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
echo -e "${BLUE}║     OPAL + OPA Access Control for Data Warehouse          ║${NC}"
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
# OPAL + OPA Configuration
# Generated automatically

# Server ports
OPAL_SERVER_PORT=7002
OPAL_CLIENT_PORT=7000
OPA_PORT=8181
OPA_STANDALONE_PORT=8182

# Logging (DEBUG, INFO, WARNING, ERROR)
OPAL_LOG_LEVEL=INFO
OPA_LOG_LEVEL=info

# For Git-based policies (production), uncomment and configure:
# OPAL_POLICY_REPO_URL=https://github.com/your-org/policies.git
# OPAL_POLICY_REPO_MAIN_BRANCH=main
# OPAL_POLICY_REPO_SSH_KEY=<base64-encoded-ssh-key>
EOF
        echo -e "${GREEN}Created .env configuration file${NC}"
    fi
}

# Function to start OPAL services
start_opal() {
    echo -e "${YELLOW}Starting OPAL + OPA services...${NC}"
    
    # Create required networks
    echo -e "${YELLOW}   Creating required networks...${NC}"
    docker network create data_warehouse_default 2>/dev/null || true
    docker network create data_warehouse_opal_opal_network 2>/dev/null || true
    
    COMPOSE_CMD=$(get_compose_cmd)
    
    # Start services in order
    echo -e "${YELLOW}   Starting broadcast channel...${NC}"
    $COMPOSE_CMD up -d broadcast_channel
    
    echo -e "${YELLOW}   Waiting for broadcast channel to be ready...${NC}"
    sleep 3
    
    echo -e "${YELLOW}   Starting OPAL server...${NC}"
    $COMPOSE_CMD up -d opal_server
    
    echo -e "${YELLOW}   Waiting for OPAL server to be ready...${NC}"
    for i in {1..30}; do
        if curl -s "http://localhost:${OPAL_SERVER_PORT:-7002}/healthcheck" > /dev/null 2>&1; then
            break
        fi
        sleep 2
    done
    
    echo -e "${YELLOW}   Starting OPAL client (with embedded OPA)...${NC}"
    $COMPOSE_CMD up -d opal_client
    
    echo -e "${GREEN}OPAL + OPA services started!${NC}"
    echo
    echo -e "${BLUE}Service URLs:${NC}"
    echo -e "  • OPAL Server:     http://localhost:${OPAL_SERVER_PORT:-7002}"
    echo -e "  • OPAL Client:     http://localhost:${OPAL_CLIENT_PORT:-7000}"
    echo -e "  • OPA (queries):   http://localhost:${OPA_PORT:-8181}"
    echo
    echo -e "${BLUE}Architecture:${NC}"
    echo "  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐"
    echo "  │  Broadcast  │◄───►│    OPAL     │◄───►│    OPAL     │"
    echo "  │  Channel    │     │   Server    │     │   Client    │"
    echo "  │ (PostgreSQL)│     │  (:7002)    │     │  (:7000)    │"
    echo "  └─────────────┘     └─────────────┘     └──────┬──────┘"
    echo "                                                  │"
    echo "                                           ┌──────▼──────┐"
    echo "                                           │  Embedded   │"
    echo "                                           │    OPA      │"
    echo "                                           │  (:8181)    │"
    echo "                                           └─────────────┘"
}

# Function to start standalone OPA only (for development/debugging)
start_standalone() {
    echo -e "${YELLOW}Starting standalone OPA (without OPAL)...${NC}"
    
    docker network create data_warehouse_default 2>/dev/null || true
    docker network create data_warehouse_opal_opal_network 2>/dev/null || true
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile standalone up -d opa_standalone
    
    echo -e "${GREEN}Standalone OPA started!${NC}"
    echo -e "  • OPA Server: http://localhost:${OPA_STANDALONE_PORT:-8182}"
}

# Function to stop OPAL services
stop_opal() {
    echo -e "${YELLOW}Stopping OPAL + OPA services...${NC}"
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile standalone down
    
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
    $COMPOSE_CMD logs -f
}

# Function to show status
show_status() {
    echo -e "${BLUE}OPAL + OPA Services Status:${NC}"
    echo
    
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD ps
    
    echo
    echo -e "${BLUE}Health Checks:${NC}"
    
    # Check Broadcast Channel
    if docker ps --format "{{.Names}}" | grep -q "data_warehouse_opal_broadcast"; then
        echo -e "  Broadcast Channel: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Broadcast Channel: ${RED}✗ Not running${NC}"
    fi
    
    # Check OPAL Server
    if curl -s "http://localhost:${OPAL_SERVER_PORT:-7002}/healthcheck" > /dev/null 2>&1; then
        echo -e "  OPAL Server:       ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  OPAL Server:       ${RED}✗ Not responding${NC}"
    fi
    
    # Check OPAL Client
    if curl -s "http://localhost:${OPAL_CLIENT_PORT:-7000}/healthcheck" > /dev/null 2>&1; then
        echo -e "  OPAL Client:       ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  OPAL Client:       ${RED}✗ Not responding${NC}"
    fi
    
    # Check OPA
    if curl -s "http://localhost:${OPA_PORT:-8181}/health" > /dev/null 2>&1; then
        echo -e "  OPA (embedded):    ${GREEN}✓ Healthy${NC}"
    else
        echo -e "  OPA (embedded):    ${RED}✗ Not responding${NC}"
    fi
    
    # Check Standalone OPA (if running)
    if curl -s "http://localhost:${OPA_STANDALONE_PORT:-8182}/health" > /dev/null 2>&1; then
        echo -e "  OPA (standalone):  ${GREEN}✓ Healthy${NC}"
    fi
}

# Function to trigger data update
trigger_update() {
    echo -e "${YELLOW}Triggering policy data update...${NC}"
    
    OPAL_SERVER_URL="http://localhost:${OPAL_SERVER_PORT:-7002}"
    
    curl -s -X POST "$OPAL_SERVER_URL/data/config" \
        -H "Content-Type: application/json" \
        -d '{
            "entries": [{
                "url": "http://opal_server:7002/policy-data",
                "topics": ["policy_data"],
                "dst_path": ""
            }]
        }'
    
    echo -e "${GREEN}Data update triggered!${NC}"
}

# Main command handling
case "${1:-}" in
    start)
        create_env
        start_opal
        ;;
    start-standalone)
        create_env
        start_standalone
        ;;
    stop)
        stop_opal
        ;;
    restart)
        stop_opal
        sleep 2
        create_env
        start_opal
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
    update)
        trigger_update
        ;;
    *)
        echo "Usage: $0 {start|start-standalone|stop|restart|test|logs|status|update}"
        echo
        echo "Commands:"
        echo "  start            Start full OPAL + OPA stack (production mode)"
        echo "  start-standalone Start only standalone OPA (development mode)"
        echo "  stop             Stop all services"
        echo "  restart          Restart all services"
        echo "  test             Run policy evaluation tests"
        echo "  logs             Show service logs"
        echo "  status           Show service status"
        echo "  update           Trigger policy data update"
        echo
        echo "Production Architecture:"
        echo "  Broadcast Channel (PostgreSQL) → OPAL Server → OPAL Client → OPA"
        echo
        echo "Service Ports:"
        echo "  OPAL Server:  7002  (policy administration)"
        echo "  OPAL Client:  7000  (client API)"
        echo "  OPA:          8181  (authorization queries)"
        exit 1
        ;;
esac
