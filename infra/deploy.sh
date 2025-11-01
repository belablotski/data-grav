#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-data-grav-rg}"
LOCATION="${LOCATION:-westus2}"
PARAMETERS_FILE="${PARAMETERS_FILE:-parameters.json}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Data-Grav Infrastructure Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
echo -e "${YELLOW}Checking Azure login status...${NC}"
az account show &> /dev/null || {
    echo -e "${RED}Not logged in to Azure${NC}"
    echo "Please run: az login"
    exit 1
}

# Display current subscription
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✓ Logged in to Azure${NC}"
echo "  Subscription: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Check if parameters file exists
if [ ! -f "$PARAMETERS_FILE" ]; then
    echo -e "${RED}Error: Parameters file '$PARAMETERS_FILE' not found${NC}"
    echo "Please create it from parameters.example.json"
    exit 1
fi

# Create resource group
echo -e "${YELLOW}Creating resource group: $RESOURCE_GROUP_NAME${NC}"
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags Project=data-grav Purpose=replication-testing \
    --output table

echo ""
echo -e "${YELLOW}Validating Bicep template...${NC}"
az deployment group validate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters "@$PARAMETERS_FILE" \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Template validation successful${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Deploying infrastructure...${NC}"
echo "This may take a few minutes..."
echo ""

DEPLOYMENT_NAME="data-grav-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters "@$PARAMETERS_FILE" \
    --name "$DEPLOYMENT_NAME" \
    --output table

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Deployment successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Get outputs
    echo -e "${YELLOW}Deployment Details:${NC}"
    STORAGE_ACCOUNT_NAME=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.storageAccountName.value -o tsv)
    
    PRIMARY_LOCATION=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.primaryLocation.value -o tsv)
    
    SECONDARY_LOCATION=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.secondaryLocation.value -o tsv)
    
    PRIMARY_ENDPOINT=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.primaryEndpoint.value -o tsv)
    
    SECONDARY_ENDPOINT=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.secondaryEndpoint.value -o tsv)
    
    echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "  Primary Region: $PRIMARY_LOCATION"
    echo "  Secondary Region: $SECONDARY_LOCATION"
    echo "  Primary Endpoint: $PRIMARY_ENDPOINT"
    echo "  Secondary Endpoint: $SECONDARY_ENDPOINT"
    echo ""
    
    # Save outputs to file
    OUTPUT_FILE="deployment-outputs.env"
    echo "# Data-Grav Deployment Outputs" > "$OUTPUT_FILE"
    echo "# Generated: $(date)" >> "$OUTPUT_FILE"
    echo "export AZURE_RESOURCE_GROUP=\"$RESOURCE_GROUP_NAME\"" >> "$OUTPUT_FILE"
    echo "export AZURE_STORAGE_ACCOUNT=\"$STORAGE_ACCOUNT_NAME\"" >> "$OUTPUT_FILE"
    echo "export AZURE_PRIMARY_LOCATION=\"$PRIMARY_LOCATION\"" >> "$OUTPUT_FILE"
    echo "export AZURE_SECONDARY_LOCATION=\"$SECONDARY_LOCATION\"" >> "$OUTPUT_FILE"
    echo "export AZURE_PRIMARY_ENDPOINT=\"$PRIMARY_ENDPOINT\"" >> "$OUTPUT_FILE"
    echo "export AZURE_SECONDARY_ENDPOINT=\"$SECONDARY_ENDPOINT\"" >> "$OUTPUT_FILE"
    
    echo -e "${GREEN}✓ Outputs saved to: $OUTPUT_FILE${NC}"
    echo ""
    echo -e "${YELLOW}To use these values, run:${NC}"
    echo "  source $OUTPUT_FILE"
    echo ""
else
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
fi
