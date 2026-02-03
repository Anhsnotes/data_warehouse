#!/bin/bash

# Data Warehouse Stack Shutdown Script
# This script stops all services in the correct order:
#
# Step 1: Airbyte (if running)
# Step 2: OPAL Access Control (if running)
# Step 3: Docker Compose services (Streamlit, dbt-docs, SQL Server, PostgreSQL)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping Data Warehouse Stack...${NC}"
echo ""

# Step 1: Stop Airbyte (if running)
echo -e "${YELLOW}Step 1: Stopping Airbyte...${NC}"

# Check for Airbyte kind cluster container (running or stopped)
AIRBYTE_CONTAINER_EXISTS=$(docker ps -a --format "{{.Names}}" | grep -c "airbyte-abctl-control-plane" || echo "0")
AIRBYTE_CONTAINER_RUNNING=$(docker ps --format "{{.Names}}" | grep -c "airbyte-abctl-control-plane" || echo "0")

if [ "$AIRBYTE_CONTAINER_RUNNING" -gt 0 ]; then
    # Container is running, stop it
    echo -e "${YELLOW}   Found running Airbyte kind cluster container. Stopping...${NC}"
    set +e
    docker stop airbyte-abctl-control-plane &> /dev/null
    STOP_RESULT=$?
    set -e
    
    if [ $STOP_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ Airbyte container stopped${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to stop Airbyte container. Attempting force stop...${NC}"
        docker kill airbyte-abctl-control-plane &> /dev/null || true
        sleep 1
        if ! docker ps --format "{{.Names}}" | grep -q "airbyte-abctl-control-plane"; then
            echo -e "${GREEN}✓ Airbyte container force stopped${NC}"
        else
            echo -e "${RED}⚠ Could not stop Airbyte container. You may need to stop it manually:${NC}"
            echo -e "${YELLOW}   docker stop airbyte-abctl-control-plane${NC}"
        fi
    fi
elif [ "$AIRBYTE_CONTAINER_EXISTS" -gt 0 ]; then
    # Container exists but is not running (already stopped)
    echo -e "${GREEN}✓ Airbyte container is already stopped${NC}"
elif command -v abctl &> /dev/null; then
    # Check status via abctl if container not found but abctl is available
    set +e
    AIRBYTE_STATUS_OUTPUT=$(abctl local status 2>&1)
    AIRBYTE_STATUS_EXIT=$?
    set -e
    
    if [ $AIRBYTE_STATUS_EXIT -eq 0 ]; then
        if echo "$AIRBYTE_STATUS_OUTPUT" | grep -qi "running\|SUCCESS.*running\|deployed"; then
            echo -e "${YELLOW}   Airbyte appears to be running but container not found.${NC}"
            echo -e "${YELLOW}   Note: abctl does not have a 'stop' command.${NC}"
            echo -e "${YELLOW}   To stop Airbyte, you may need to uninstall: abctl local uninstall${NC}"
        else
            echo -e "${GREEN}✓ Airbyte is not running${NC}"
        fi
    else
        echo -e "${GREEN}✓ Airbyte is not running (container not found)${NC}"
    fi
else
    echo -e "${GREEN}✓ Airbyte is not running (no containers found)${NC}"
fi
echo ""

# Step 2: Stop OPAL Access Control (if running)
echo -e "${YELLOW}Step 2: Stopping OPAL Access Control...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if OPAL containers are running
OPAL_RUNNING=$(docker ps --format "{{.Names}}" | grep -c "data_warehouse_opal" 2>/dev/null || echo 0)

if [ "${OPAL_RUNNING:-0}" -gt 0 ]; then
    echo -e "${YELLOW}   Found running OPAL services. Stopping...${NC}"
    
    if [ -f "$SCRIPT_DIR/opal/setup.sh" ]; then
        cd "$SCRIPT_DIR/opal"
        ./setup.sh stop
        cd "$SCRIPT_DIR"
        echo -e "${GREEN}✓ OPAL + OPA services stopped${NC}"
    else
        # Fallback: stop containers directly
        set +e
        docker stop data_warehouse_opal_server data_warehouse_opal_client data_warehouse_opal_broadcast data_warehouse_opa_standalone 2>/dev/null
        set -e
        echo -e "${GREEN}✓ OPAL containers stopped${NC}"
    fi
else
    # Check for stopped OPAL containers
    OPAL_EXISTS=$(docker ps -a --format "{{.Names}}" | grep -c "data_warehouse_opal" 2>/dev/null || echo 0)
    if [ "${OPAL_EXISTS:-0}" -gt 0 ]; then
        echo -e "${GREEN}✓ OPAL services are already stopped${NC}"
    else
        echo -e "${GREEN}✓ OPAL is not running (no containers found)${NC}"
    fi
fi
echo ""

# Step 3: Stop Docker Compose services
echo -e "${YELLOW}Step 3: Stopping Docker Compose services...${NC}"
if docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}   Stopping containers...${NC}"
    docker-compose down
    echo -e "${GREEN}✓ All Docker Compose services stopped${NC}"
else
    echo -e "${GREEN}✓ No Docker Compose services running${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All services stopped successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Services Stopped:${NC}"
echo "  • PostgreSQL        (localhost:5432)"
echo "  • Streamlit         (http://localhost:8501)"
echo "  • dbt Docs          (http://localhost:8080)"
echo "  • SQL Server        (localhost:1433)"
echo "  • Airbyte           (http://localhost:8000)"
echo "  • OPAL Server       (http://localhost:7002)"
echo "  • OPAL Client       (http://localhost:7001)"
echo "  • OPA (via OPAL)    (http://localhost:8183)"
echo "  • OPA (standalone)  (http://localhost:8181)"
echo ""
echo -e "${BLUE}To start services again:${NC}"
echo "  ./start.sh                           # Start all services (OPAL enabled by default)"
echo "  OPAL_ENABLED=false ./start.sh        # Start without OPAL access control"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  View stopped containers:   docker-compose ps -a"
echo "  Remove volumes (⚠️ data):   docker-compose down -v"
echo "  Check Airbyte status:      abctl local status"
echo "  OPAL status:               cd opal && ./setup.sh status"
echo ""

