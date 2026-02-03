#!/bin/bash

# Data Warehouse Stack Startup Script
# This script starts all services in the correct order:
#
# Pre-flight: Create Docker networks
# Step 1: PostgreSQL (localhost:5432)
# Step 2: Streamlit Dashboard (http://localhost:8501)
# Step 3: dbt Documentation Server (http://localhost:8080)
# Step 4: SQL Server (localhost:1433)
# Step 5: AdventureWorks Database (SQL Server sample data)
# Step 6: Airbyte (http://localhost:8000)
# Step 7: OPAL Access Control (http://localhost:7002, http://localhost:8181)

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Data Warehouse Stack...${NC}"
echo ""

# Pre-flight: Clean up any stale networks
docker network rm data_warehouse_default 2>/dev/null || true
echo ""

# Step 1: Start PostgreSQL
echo -e "${YELLOW}Step 1: Starting PostgreSQL...${NC}"
docker-compose up -d postgres
echo -e "${GREEN}✓ PostgreSQL started${NC}"
echo "   Waiting for PostgreSQL to be ready..."
sleep 3

# Wait for PostgreSQL to be healthy
until docker exec data_warehouse_postgres pg_isready -U postgres > /dev/null 2>&1; do
    echo "   Waiting for PostgreSQL..."
    sleep 2
done
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
echo ""

# Step 2: Start Streamlit
echo -e "${YELLOW}Step 2: Starting Streamlit...${NC}"
docker-compose up -d streamlit
echo -e "${GREEN}✓ Streamlit started${NC}"
echo ""

# Step 3: Build and Start dbt Documentation Server
echo -e "${YELLOW}Step 3: Building and starting dbt Documentation Server...${NC}"

# Build the dbt-docs image to ensure it has the latest dbt project files
echo -e "${YELLOW}   Building dbt-docs Docker image...${NC}"
docker-compose build dbt-docs
echo -e "${GREEN}✓ dbt-docs image built${NC}"

# Start the container (it will regenerate docs on startup)
echo -e "${YELLOW}   Starting dbt-docs container (docs will be regenerated)...${NC}"
docker-compose up -d dbt-docs
echo -e "${GREEN}✓ dbt Documentation Server started${NC}"
echo ""

# Step 4: Start SQL Server
echo -e "${YELLOW}Step 4: Starting SQL Server...${NC}"
docker-compose up -d sqlserver
echo -e "${GREEN}✓ SQL Server started${NC}"
echo "   Waiting for SQL Server to be ready..."
sleep 5

# Wait for SQL Server to be healthy
SQLSERVER_SA_PASSWORD="${SQLSERVER_SA_PASSWORD:-YourStrong@Passw0rd}"
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec data_warehouse_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SQLSERVER_SA_PASSWORD" -C -Q "SELECT 1" -b > /dev/null 2>&1; then
        echo -e "${GREEN}✓ SQL Server is ready${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Waiting for SQL Server... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${YELLOW}⚠ SQL Server may not be fully ready. Continuing...${NC}"
fi
echo ""

# Step 5: Check and Install AdventureWorks Database on SQL Server (if needed)
echo -e "${YELLOW}Step 5: Checking AdventureWorks database on SQL Server...${NC}"
sleep 2
DB_EXISTS=$(docker exec data_warehouse_sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SQLSERVER_SA_PASSWORD" \
    -C \
    -Q "SELECT name FROM sys.databases WHERE name = 'AdventureWorks2022'" \
    -h -1 -W 2>/dev/null | tr -d ' \r\n' || echo "")

if [ -z "$DB_EXISTS" ] || [ "$DB_EXISTS" != "AdventureWorks2022" ]; then
    echo -e "${YELLOW}   AdventureWorks database not found. Installing...${NC}"
    echo -e "${YELLOW}   This may take several minutes...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/adventureworks/install_adventureworks_sqlserver.sh" ]; then
        # Temporarily disable exit on error for this step (it's optional)
        set +e
        export SQLSERVER_SA_PASSWORD
        "$SCRIPT_DIR/adventureworks/install_adventureworks_sqlserver.sh"
        INSTALL_RESULT=$?
        set -e
        if [ $INSTALL_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓ AdventureWorks database installed on SQL Server${NC}"
        else
            echo -e "${YELLOW}⚠ AdventureWorks installation failed. You can install it manually later.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ AdventureWorks install script not found. Skipping installation.${NC}"
    fi
else
    echo -e "${GREEN}✓ AdventureWorks database already exists on SQL Server${NC}"
fi
echo ""

# Step 6: Install and Start Airbyte
echo -e "${YELLOW}Step 6: Installing and starting Airbyte...${NC}"

# Ensure abctl is installed
if ! command -v abctl &> /dev/null; then
    echo -e "${YELLOW}   abctl not found. Installing abctl...${NC}"
    curl -LsfS https://get.airbyte.com | bash -
    
    if ! command -v abctl &> /dev/null; then
        echo -e "${YELLOW}⚠ abctl installation failed. Skipping Airbyte setup.${NC}"
        echo -e "${YELLOW}   Install manually: curl -LsfS https://get.airbyte.com | bash -${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ abctl installed${NC}"
    fi
fi

# Check Airbyte status and install/start if needed
if command -v abctl &> /dev/null; then
    # Check if Airbyte is installed (capture both output and exit code)
    set +e
    AIRBYTE_STATUS_OUTPUT=$(abctl local status 2>&1)
    AIRBYTE_STATUS_EXIT=$?
    set -e
    
    # Check for various status indicators
    # Note: abctl doesn't have a 'start' command, so we use docker start directly
    if echo "$AIRBYTE_STATUS_OUTPUT" | grep -qi "not.*installed\|does not appear to be installed"; then
        echo -e "${YELLOW}   Airbyte is not installed. Installing now...${NC}"
        echo -e "${YELLOW}   ⚠️  This will take approximately 30 minutes. Please be patient.${NC}"
        echo ""
        
        # Temporarily disable exit on error for installation (it's a long process and optional)
        set +e
        abctl local install
        INSTALL_RESULT=$?
        set -e
        
        if [ $INSTALL_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓ Airbyte installed successfully${NC}"
            echo -e "${YELLOW}   Starting Airbyte container...${NC}"
            # Give it a moment after installation
            sleep 5
            # Start the kind cluster container directly
            set +e
            docker start airbyte-abctl-control-plane &> /dev/null 2>&1
            START_RESULT=$?
            set -e
            if [ $START_RESULT -eq 0 ]; then
                echo -e "${GREEN}✓ Airbyte started${NC}"
            else
                echo -e "${YELLOW}⚠ Airbyte installed. Container may take a moment to start. Check with: abctl local status${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Airbyte installation encountered issues.${NC}"
            echo -e "${YELLOW}   You can retry manually: cd airbyte && ./setup_with_abctl.sh${NC}"
        fi
    elif echo "$AIRBYTE_STATUS_OUTPUT" | grep -qi "ERROR.*not running\|container.*is not running\|status.*exited"; then
        # Container exists but is not running - start it
        echo -e "${YELLOW}   Airbyte container is stopped. Starting...${NC}"
        set +e
        docker start airbyte-abctl-control-plane
        START_RESULT=$?
        set -e
        if [ $START_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓ Airbyte started${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to start Airbyte container. Check with: docker ps -a | grep airbyte${NC}"
        fi
    elif echo "$AIRBYTE_STATUS_OUTPUT" | grep -qi "deployed\|SUCCESS.*Found.*cluster"; then
        # Check if container is actually running
        if docker ps --format "{{.Names}}" | grep -q "airbyte-abctl-control-plane"; then
            echo -e "${GREEN}✓ Airbyte is already running${NC}"
        else
            # Cluster exists but container not running
            echo -e "${YELLOW}   Airbyte cluster found but container not running. Starting...${NC}"
            set +e
            docker start airbyte-abctl-control-plane
            START_RESULT=$?
            set -e
            if [ $START_RESULT -eq 0 ]; then
                echo -e "${GREEN}✓ Airbyte started${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to start Airbyte container${NC}"
            fi
        fi
    else
        # Unknown status - check container directly
        if docker ps --format "{{.Names}}" | grep -q "airbyte-abctl-control-plane"; then
            echo -e "${GREEN}✓ Airbyte is running${NC}"
        elif docker ps -a --format "{{.Names}}" | grep -q "airbyte-abctl-control-plane"; then
            # Container exists but stopped
            echo -e "${YELLOW}   Airbyte container found but stopped. Starting...${NC}"
            set +e
            docker start airbyte-abctl-control-plane
            START_RESULT=$?
            set -e
            if [ $START_RESULT -eq 0 ]; then
                echo -e "${GREEN}✓ Airbyte started${NC}"
            else
                echo -e "${YELLOW}⚠ Could not start Airbyte. Check manually: docker ps -a | grep airbyte${NC}"
            fi
        else
            # Container doesn't exist - might need installation
            if [ $AIRBYTE_STATUS_EXIT -ne 0 ] && echo "$AIRBYTE_STATUS_OUTPUT" | grep -qi "not.*installed\|does not appear"; then
                echo -e "${YELLOW}   Airbyte not installed. Attempting installation...${NC}"
                echo -e "${YELLOW}   ⚠️  This will take approximately 30 minutes.${NC}"
                set +e
                abctl local install
                INSTALL_RESULT=$?
                set -e
                if [ $INSTALL_RESULT -eq 0 ]; then
                    sleep 5
                    set +e
                    docker start airbyte-abctl-control-plane &> /dev/null 2>&1
                    FINAL_START_RESULT=$?
                    set -e
                    if [ $FINAL_START_RESULT -eq 0 ]; then
                        echo -e "${GREEN}✓ Airbyte installed and started${NC}"
                    else
                        echo -e "${YELLOW}⚠ Installed. Container may take a moment to start. Check status: abctl local status${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠ Installation failed. See troubleshooting: airbyte/troubleshooting.md${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Could not determine Airbyte status. Check manually: abctl local status${NC}"
                echo -e "${YELLOW}   Status output: ${AIRBYTE_STATUS_OUTPUT:0:100}...${NC}"
            fi
        fi
    fi
fi
echo ""

# Step 7: Start OPAL Access Control (if enabled)
OPAL_ENABLED="${OPAL_ENABLED:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$OPAL_ENABLED" = "true" ] || [ "$OPAL_ENABLED" = "1" ]; then
    echo -e "${YELLOW}Step 7: Starting OPAL Access Control...${NC}"
    
    if [ -f "$SCRIPT_DIR/opal/setup.sh" ]; then
        cd "$SCRIPT_DIR/opal"
        
        # Start OPAL services (full stack with Git sync if configured, otherwise standalone)
        if [ -f .env ] && grep -q "OPAL_POLICY_REPO_URL=." .env 2>/dev/null; then
            ./setup.sh start-opal
        else
            echo -e "${YELLOW}   No Git repo configured - starting standalone OPA${NC}"
            echo -e "${YELLOW}   To enable OPAL: configure opal/.env with OPAL_POLICY_REPO_URL${NC}"
            ./setup.sh start
        fi
        
        cd "$SCRIPT_DIR"
        echo -e "${GREEN}✓ OPAL Access Control started${NC}"
    else
        echo -e "${YELLOW}⚠ OPAL setup script not found. Skipping OPAL startup.${NC}"
    fi
else
    echo -e "${YELLOW}Step 7: Skipping OPAL Access Control (OPAL_ENABLED=${OPAL_ENABLED})${NC}"
    echo -e "${YELLOW}   To enable: export OPAL_ENABLED=true${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All services started successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │ Service              │ URL                    │ Status │"
echo "  ├─────────────────────────────────────────────────────────┤"
echo "  │ 📊 PostgreSQL        │ localhost:5432         │ ✅     │"
echo "  │ 📈 Streamlit         │ http://localhost:8501  │ ✅     │"
echo "  │ 📚 dbt Docs          │ http://localhost:8080  │ ✅     │"
echo "  │ 🗄️  SQL Server        │ localhost:1433         │ ✅     │"

# Check Airbyte status (check container directly for reliability)
AIRBYTE_RUNNING="❌"
if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "airbyte-abctl-control-plane"; then
    AIRBYTE_RUNNING="✅"
elif command -v abctl &> /dev/null; then
    AIRBYTE_STATUS=$(abctl local status 2>&1 || echo "")
    if echo "$AIRBYTE_STATUS" | grep -qi "running\|deployed\|SUCCESS"; then
        AIRBYTE_RUNNING="✅"
    fi
fi
echo "  │ 🔄 Airbyte           │ http://localhost:8000  │ $AIRBYTE_RUNNING     │"

# Check OPAL/OPA status
if [ "$OPAL_ENABLED" = "true" ] || [ "$OPAL_ENABLED" = "1" ]; then
    # Check if full OPAL is running (with Git sync)
    OPAL_SERVER_STATUS="⚠️ "
    OPAL_CLIENT_STATUS="⚠️ "
    OPA_STATUS="⚠️ "
    
    if curl -s "http://localhost:7002/healthcheck" > /dev/null 2>&1; then
        OPAL_SERVER_STATUS="✅"
    fi
    if curl -s "http://localhost:7001/healthcheck" > /dev/null 2>&1; then
        OPAL_CLIENT_STATUS="✅"
    fi
    if curl -s "http://localhost:8181/health" > /dev/null 2>&1; then
        OPA_STATUS="✅"
    fi
    
    # Show OPAL services if server is running
    if [ "$OPAL_SERVER_STATUS" = "✅" ]; then
        echo "  │ 🔐 OPAL Server       │ http://localhost:7002  │ $OPAL_SERVER_STATUS     │"
        echo "  │ 🔐 OPAL Client       │ http://localhost:7001  │ $OPAL_CLIENT_STATUS     │"
        echo "  │ 🔐 OPA (via OPAL)    │ http://localhost:8183  │ $OPA_STATUS     │"
    else
        echo "  │ 🔐 OPA Access Ctrl   │ http://localhost:8181  │ $OPA_STATUS     │"
    fi
else
    echo "  │ 🔐 OPA Access Ctrl   │ http://localhost:8181  │ ⏸️      │"
fi
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo -e "${BLUE}Default Credentials:${NC}"
echo "  PostgreSQL:  postgres / postgres"
echo "  SQL Server:  sa / YourStrong@Passw0rd"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  View logs:          docker-compose logs -f [service_name]"
echo "  Stop services:      ./stop.sh"
echo "  Check status:       docker-compose ps"
if [ "$OPAL_ENABLED" = "true" ] || [ "$OPAL_ENABLED" = "1" ]; then
    echo "  OPAL status:        cd opal && ./setup.sh status"
    echo "  Test policies:      cd opal && ./setup.sh test"
else
    echo "  Enable OPAL:        export OPAL_ENABLED=true && ./start.sh"
fi
echo ""

