#!/bin/bash

##############################################################################
# Measure Data Volume in Azure Blob Storage Container
##############################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load deployment outputs if available
if [ -f "$SCRIPT_DIR/../../infra/deployment-outputs.env" ]; then
    source "$SCRIPT_DIR/../../infra/deployment-outputs.env"
fi

# Default container
CONTAINER=${1:-data-grav}
PREFIX=${2:-}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Data Volume Measurement${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${BLUE}Storage Account: ${YELLOW}${AZURE_STORAGE_ACCOUNT}${NC}"
echo -e "${BLUE}Container:       ${YELLOW}${CONTAINER}${NC}"
if [ -n "$PREFIX" ]; then
    echo -e "${BLUE}Prefix Filter:   ${YELLOW}${PREFIX}${NC}"
fi
echo ""

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1099511627776 ]; then
        echo "$(awk "BEGIN {printf \"%.2f TB\", $bytes/1099511627776}")"
    elif [ $bytes -gt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}")"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}")"
    elif [ $bytes -gt 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f KB\", $bytes/1024}")"
    else
        echo "${bytes} bytes"
    fi
}

# Get blob list
echo -e "${BLUE}Fetching blob information...${NC}"
echo ""

if [ -n "$PREFIX" ]; then
    BLOB_DATA=$(az storage blob list \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --prefix "$PREFIX" \
        --auth-mode key \
        --query "[].{name:name, size:properties.contentLength}" \
        --output json 2>/dev/null)
else
    BLOB_DATA=$(az storage blob list \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --container-name "$CONTAINER" \
        --auth-mode key \
        --query "[].{name:name, size:properties.contentLength}" \
        --output json 2>/dev/null)
fi

# Count blobs
BLOB_COUNT=$(echo "$BLOB_DATA" | jq '. | length')

if [ "$BLOB_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No blobs found.${NC}"
    exit 0
fi

# Calculate total size
TOTAL_BYTES=$(echo "$BLOB_DATA" | jq '[.[].size] | add')

# Calculate statistics
MIN_BYTES=$(echo "$BLOB_DATA" | jq '[.[].size] | min')
MAX_BYTES=$(echo "$BLOB_DATA" | jq '[.[].size] | max')
AVG_BYTES=$(echo "$BLOB_DATA" | jq "[.[].size] | add / length | floor")

# Display results
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}Total Blobs:    ${YELLOW}${BLOB_COUNT}${NC}"
echo -e "${GREEN}Total Size:     ${YELLOW}$(format_bytes $TOTAL_BYTES) ${NC}${BLUE}($TOTAL_BYTES bytes)${NC}"
echo ""
echo -e "${GREEN}Largest Blob:   ${YELLOW}$(format_bytes $MAX_BYTES)${NC}"
echo -e "${GREEN}Smallest Blob:  ${YELLOW}$(format_bytes $MIN_BYTES)${NC}"
echo -e "${GREEN}Average Size:   ${YELLOW}$(format_bytes $AVG_BYTES)${NC}"
echo ""

# Show top 10 largest blobs
echo -e "${CYAN}Top 10 Largest Blobs:${NC}"
echo -e "${CYAN}----------------------------------------${NC}"
echo "$BLOB_DATA" | jq -r 'sort_by(.size) | reverse | .[0:10] | .[] | "\(.name): \(.size)"' | while read line; do
    NAME=$(echo "$line" | cut -d: -f1)
    SIZE=$(echo "$line" | cut -d: -f2 | xargs)
    echo -e "  ${BLUE}${NAME}${NC}: ${YELLOW}$(format_bytes $SIZE)${NC}"
done

echo ""
