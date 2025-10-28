# Infrastructure Deployment

This directory contains Bicep templates and deployment scripts for provisioning Azure Storage accounts with geo-replication for testing purposes.

## Prerequisites

- Azure CLI installed (`az --version`)
- Azure subscription with appropriate permissions
- Logged in to Azure CLI (`az login`)

## Files

- `main.bicep` - Main Bicep template for storage account and configuration
- `parameters.json` - Deployment parameters (customize this)
- `parameters.example.json` - Example parameters file
- `deploy.sh` - Automated deployment script
- `destroy.sh` - Cleanup script to remove all resources

## Quick Start

### 1. Configure Parameters

Copy the example parameters file and customize it:

```bash
cp parameters.example.json parameters.json
```

Edit `parameters.json` and set:
- `storageAccountName` - Must be globally unique (3-24 lowercase alphanumeric)
- `replicationType` - Choose your replication strategy
- Other settings as needed

### 2. Deploy Infrastructure

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Check Azure CLI installation and login status
2. Create resource group
3. Validate the Bicep template
4. Deploy the infrastructure
5. Save outputs to `deployment-outputs.env`

### 3. Use the Outputs

Load the deployment outputs into your environment:

```bash
source deployment-outputs.env
```

## Replication Types

Choose the appropriate replication type based on your testing needs:

| Type | Description | Secondary Read | Use Case |
|------|-------------|----------------|----------|
| `Standard_GRS` | Geo-Redundant Storage | ❌ No | Basic geo-replication testing |
| `Standard_RAGRS` | Read-Access GRS | ✅ Yes | **Recommended for testing** |
| `Standard_GZRS` | Geo-Zone-Redundant | ❌ No | Zone + geo redundancy |
| `Standard_RAGZRS` | Read-Access GZRS | ✅ Yes | Maximum availability testing |

**Note**: For replication monitoring, you need **RA-GRS** or **RA-GZRS** to read from the secondary region.

## Features Included

✅ **Storage Account** with geo-replication  
✅ **Blob versioning** enabled  
✅ **Change feed** for tracking modifications  
✅ **Soft delete** with configurable retention  
✅ **HTTPS-only** traffic  
✅ **TLS 1.2** minimum  
✅ **Private access** (no public blob access)  
✅ **Diagnostic settings** for monitoring  
✅ **Multiple containers** (test-data, replication-test, performance-test)  

## Manual Deployment

If you prefer manual deployment:

```bash
# Set variables
RESOURCE_GROUP="data-grav-rg"
LOCATION="westus2"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Validate template
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters @parameters.json

# Deploy
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters @parameters.json \
  --name data-grav-deployment
```

## View Deployment Details

```bash
# List all resources in the group
az resource list --resource-group data-grav-rg --output table

# Get storage account details
az storage account show \
  --name <storage-account-name> \
  --resource-group data-grav-rg

# Get connection string
az storage account show-connection-string \
  --name <storage-account-name> \
  --resource-group data-grav-rg
```

## Cleanup

To delete all resources:

```bash
chmod +x destroy.sh
./destroy.sh
```

**⚠️ WARNING**: This will permanently delete the resource group and all its resources!

## Cost Considerations

- **Storage costs** vary by region and replication type
- **RA-GRS/RA-GZRS** is more expensive than GRS/GZRS
- **Egress charges** apply when reading from secondary region
- **Operations costs** (write/read/list operations)

Estimate costs: [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)

## Troubleshooting

### Storage account name already exists
Storage account names must be globally unique. Try a different name.

### Insufficient permissions
Ensure you have `Contributor` or `Owner` role on the subscription.

### Deployment validation fails
Check the error message and verify all parameters are correct.

### Secondary endpoint not available
- Ensure you're using RA-GRS or RA-GZRS
- Secondary endpoints may take a few minutes to become available

## Outputs

After deployment, these outputs are available:

- `storageAccountName` - Name of the storage account
- `primaryEndpoint` - Primary blob endpoint URL
- `secondaryEndpoint` - Secondary blob endpoint URL  
- `primaryLocation` - Primary region
- `secondaryLocation` - Secondary (paired) region
- `connectionString` - Connection string for storage access
- `containerNames` - List of created containers

## Security Notes

- Connection strings contain sensitive information - keep them secure
- Consider using Azure Key Vault for production deployments
- Enable Azure Defender for Storage for threat detection
- Use Managed Identities instead of connection strings when possible

## Next Steps

After deployment:
1. Test connectivity to primary endpoint
2. Upload test data
3. Verify secondary endpoint accessibility (RA-GRS/RA-GZRS only)
4. Run replication monitoring tools
5. Monitor metrics in Azure Portal

## Resources

- [Azure Storage Redundancy](https://docs.microsoft.com/azure/storage/common/storage-redundancy)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Storage Blob SDK](https://docs.microsoft.com/azure/storage/blobs/)
