#!/bin/zsh

# Antigravity Quota Fetcher
# Discovers the local Antigravity Language Server and fetches quota data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "${CYAN}🚀 Antigravity Quota Fetcher${NC}"
echo "================================"

# Step 1: Find Antigravity Language Server process
echo "\n${YELLOW}[1/4] Searching for Antigravity Language Server...${NC}"

PROCESS_INFO=$(ps aux | grep -E "language_server_macos" | grep -v grep | head -n 1)

if [[ -z "$PROCESS_INFO" ]]; then
    echo "${RED}❌ No Antigravity Language Server process found.${NC}"
    echo "   Make sure Antigravity is running."
    exit 1
fi

# Extract PID
PID=$(echo "$PROCESS_INFO" | awk '{print $2}')
echo "   Found process with PID: ${GREEN}$PID${NC}"

# Step 2: Extract CSRF token from process arguments
echo "\n${YELLOW}[2/4] Extracting CSRF token...${NC}"

CSRF_TOKEN=$(echo "$PROCESS_INFO" | grep -oE '\-\-csrf_token [a-f0-9-]+' | awk '{print $2}')

if [[ -z "$CSRF_TOKEN" ]]; then
    echo "${RED}❌ Could not extract CSRF token from process arguments.${NC}"
    exit 1
fi

echo "   CSRF Token: ${GREEN}${CSRF_TOKEN:0:8}...${NC} (truncated for security)"

# Step 3: Find listening ports for this process
echo "\n${YELLOW}[3/4] Finding listening ports...${NC}"

PORTS=$(lsof -i -P -n 2>/dev/null | grep "$PID" | grep LISTEN | awk '{print $9}' | sed 's/.*://' | sort -u)

if [[ -z "$PORTS" ]]; then
    echo "${RED}❌ No listening ports found for PID $PID.${NC}"
    exit 1
fi

echo "   Found ports: ${GREEN}$(echo $PORTS | tr '\n' ' ')${NC}"

# Step 4: Try each port until we get a successful response
echo "\n${YELLOW}[4/4] Testing ports for API access...${NC}"

WORKING_PORT=""
for PORT in ${(f)PORTS}; do
    echo -n "   Trying port $PORT... "
    
    RESPONSE=$(curl -sk -X POST \
        "https://127.0.0.1:$PORT/exa.language_server_pb.LanguageServerService/GetUserStatus" \
        -H "Content-Type: application/json" \
        -H "Connect-Protocol-Version: 1" \
        -H "X-Codeium-Csrf-Token: $CSRF_TOKEN" \
        -d '{}' \
        --max-time 2 \
        2>/dev/null) || RESPONSE=""
    
    if [[ -n "$RESPONSE" && "$RESPONSE" != *"error"* && "$RESPONSE" == *"{"* ]]; then
        echo "${GREEN}✓ Success!${NC}"
        WORKING_PORT=$PORT
        break
    else
        echo "${RED}✗${NC}"
    fi
done

if [[ -z "$WORKING_PORT" ]]; then
    echo "\n${RED}❌ Could not connect to any port.${NC}"
    exit 1
fi

# Output the quota data
echo "\n${GREEN}================================${NC}"
echo "${GREEN}✅ Connected to port $WORKING_PORT${NC}"
echo "${GREEN}================================${NC}"
echo "\n${CYAN}Quota Data:${NC}\n"

# Pretty print if jq is available, otherwise raw output
if command -v jq &> /dev/null; then
    echo "$RESPONSE" | jq '.'
else
    echo "$RESPONSE"
fi

# Optional: Extract and display key quota info
echo "\n${CYAN}--------------------------------${NC}"
echo "${CYAN}Quick Summary:${NC}"

if command -v jq &> /dev/null; then
    # Extract model quotas if jq is available
    echo "$RESPONSE" | jq -r '
        .clientModelConfigs // {} | to_entries[] | 
        select(.value.quotaInfo != null) |
        "\(.value.displayLabel // .key): \((.value.quotaInfo.remainingFraction // 0) * 100 | floor)% remaining"
    ' 2>/dev/null || echo "   (Install jq for detailed quota breakdown)"
else
    echo "   (Install jq for detailed quota breakdown)"
fi
