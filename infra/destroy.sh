#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-data-grav-rg}"

echo -e "${RED}========================================${NC}"
echo -e "${RED}Data-Grav Infrastructure Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    exit 1
fi

# Check if logged in
az account show &> /dev/null || {
    echo -e "${RED}Not logged in to Azure${NC}"
    echo "Please run: az login"
    exit 1
}

# Check if resource group exists
if ! az group exists --name "$RESOURCE_GROUP_NAME" | grep -q true; then
    echo -e "${YELLOW}Resource group '$RESOURCE_GROUP_NAME' does not exist${NC}"
    exit 0
fi

echo -e "${YELLOW}WARNING: This will delete the following resource group and ALL its resources:${NC}"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo ""

# List resources in the group
echo -e "${YELLOW}Resources to be deleted:${NC}"
az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type}" -o table
echo ""

# Confirmation
read -p "Are you sure you want to delete these resources? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
read -p "Please type the resource group name to confirm: " CONFIRM_NAME
if [ "$CONFIRM_NAME" != "$RESOURCE_GROUP_NAME" ]; then
    echo -e "${RED}Resource group name does not match. Cleanup cancelled${NC}"
    exit 1
fi

echo ""
echo -e "${RED}Deleting resource group: $RESOURCE_GROUP_NAME${NC}"
echo "This may take several minutes..."
echo ""

az group delete \
    --name "$RESOURCE_GROUP_NAME" \
    --yes \
    --no-wait

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Cleanup initiated${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Note: Deletion is running in the background${NC}"
echo "To check status, run:"
echo "  az group show --name $RESOURCE_GROUP_NAME"
echo ""
