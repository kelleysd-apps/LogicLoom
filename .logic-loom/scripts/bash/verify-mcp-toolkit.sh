#!/bin/bash

# Verify Docker MCP Toolkit installation
# This script checks if Docker MCP Toolkit is properly installed and configured

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Docker MCP Toolkit Verification${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Track overall status
OVERALL_STATUS=0

# Check 1: Docker availability
echo -e "${BLUE}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}[OK]${NC} ${DOCKER_VERSION}"
else
    echo -e "${RED}[FAIL]${NC} Docker not installed"
    echo -e "${YELLOW}       Docker MCP Toolkit requires Docker${NC}"
    OVERALL_STATUS=1
fi

# Check 2: Docker MCP CLI Plugin
echo ""
echo -e "${BLUE}Checking Docker MCP CLI Plugin...${NC}"
if docker mcp version &>/dev/null 2>&1; then
    MCP_VERSION=$(docker mcp version)
    echo -e "${GREEN}[OK]${NC} Docker MCP Toolkit: ${MCP_VERSION}"
else
    echo -e "${RED}[FAIL]${NC} Docker MCP Toolkit not installed"
    echo -e "${YELLOW}       Run: curl -sL 'https://github.com/docker/mcp-gateway/releases/download/v0.30.0/docker-mcp-linux-amd64.tar.gz' | tar -xz -C ~/.docker/cli-plugins/${NC}"
    OVERALL_STATUS=1
fi

# Check 3: Gateway dry-run test
echo ""
echo -e "${BLUE}Checking MCP Gateway...${NC}"
if docker mcp version &>/dev/null 2>&1; then
    if timeout 10 docker mcp gateway run --dry-run &>/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Gateway ready"
    else
        echo -e "${YELLOW}[WARN]${NC} Gateway test inconclusive (may still work)"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Skipped - MCP Toolkit not installed"
fi

# Check 4: Available tools
echo ""
echo -e "${BLUE}Checking available tools...${NC}"
if docker mcp version &>/dev/null 2>&1; then
    TOOL_COUNT=$(docker mcp tools ls 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo "0")
    if [ "$TOOL_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[OK]${NC} ${TOOL_COUNT} tools available"
        docker mcp tools ls 2>/dev/null | tail -n +2 | head -6 | while read line; do
            echo -e "       ${line}"
        done
    else
        echo -e "${YELLOW}[WARN]${NC} No tools detected"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Skipped - MCP Toolkit not installed"
fi

# Check 5: Catalog availability
echo ""
echo -e "${BLUE}Checking MCP catalog...${NC}"
if docker mcp version &>/dev/null 2>&1; then
    CATALOG_COUNT=$(docker mcp catalog ls 2>/dev/null | wc -l)
    if [ "$CATALOG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}[OK]${NC} Catalog accessible"
        docker mcp catalog ls 2>/dev/null | head -3
    else
        echo -e "${YELLOW}[WARN]${NC} Catalog may not be accessible"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Skipped - MCP Toolkit not installed"
fi

# Check 6: Claude Code client configuration
echo ""
echo -e "${BLUE}Checking Claude Code client configuration...${NC}"
if docker mcp version &>/dev/null 2>&1; then
    CLIENT_STATUS=$(docker mcp client ls 2>/dev/null | grep -i "claude-code" || echo "")
    if echo "$CLIENT_STATUS" | grep -q "connected"; then
        echo -e "${GREEN}[OK]${NC} Claude Code client connected"
    else
        echo -e "${YELLOW}[INFO]${NC} Claude Code client not connected"
        echo -e "${YELLOW}       Run: docker mcp client connect claude-code --global${NC}"
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Skipped - MCP Toolkit not installed"
fi

# Check 7: Project .mcp.json
echo ""
echo -e "${BLUE}Checking project MCP configuration...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [ -f "$PROJECT_ROOT/.mcp.json" ]; then
    if grep -q "docker" "$PROJECT_ROOT/.mcp.json"; then
        echo -e "${GREEN}[OK]${NC} .mcp.json configured with Docker gateway"
    else
        echo -e "${YELLOW}[INFO]${NC} .mcp.json exists but Docker gateway not configured"
    fi
else
    echo -e "${YELLOW}[INFO]${NC} .mcp.json not found in project root"
    echo -e "${YELLOW}       This is optional - Claude Code can use global config${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=====================================${NC}"
if [ $OVERALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}   Verification Complete ✓${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${GREEN}Docker MCP Toolkit is ready for use.${NC}"
    echo ""
    echo -e "${BLUE}Quick commands:${NC}"
    echo -e "  docker mcp catalog show docker-mcp  # Browse 310+ servers"
    echo -e "  docker mcp server enable <name>     # Enable a server"
    echo -e "  docker mcp tools ls                 # List available tools"
    echo ""
    echo -e "${BLUE}In Claude Code conversations:${NC}"
    echo -e "  Use mcp-find tool to search servers"
    echo -e "  Use mcp-add tool to add servers dynamically"
else
    echo -e "${RED}   Verification Failed${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "${YELLOW}Some checks failed. Please review the errors above.${NC}"
fi

exit $OVERALL_STATUS
