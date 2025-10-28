# Data-Grav: Azure Blob Storage Replication Testing Tool

A comprehensive testing suite for Azure Blob Storage replication scenarios and Azure Storage Actions. This project helps you test and monitor geo-replication behavior, measure replication lag, and validate data consistency across Azure regions.

**Status:**
1. Infra setup works
2. Data generation + upload works

## Overview

Data-Grav provides tools to:
- Generate massive amounts of test data (text and binary)
- Upload data to Azure Blob Storage in primary region
- Monitor and verify data replication to secondary region
- Measure replication lag and performance metrics
- Test Azure Storage Actions and lifecycle policies

## Project Structure

```
data-grav/
├── src/
│   ├── data-generator/      # Data generation utilities
│   ├── replication-monitor/ # Replication monitoring tools
│   └── storage-actions/     # Azure Storage Actions tests
├── infra/                   # Infrastructure deployment scripts
├── tests/                   # Unit and integration tests
├── docs/                    # Additional documentation
└── README.md
```

## Features

### 1. Data Generator
- **Text Data Generation**: Generate large text files by duplicating strings
- **Binary Data Generation**: Create binary files through array duplication
- **Configurable Size**: Generate files from KB to GB range
- **Performance Optimized**: Efficient memory usage for large file generation

### 2. Replication Monitor
- **Real-time Monitoring**: Track data availability in secondary region
- **Lag Measurement**: Calculate replication lag between regions
- **Automated Verification**: Compare checksums/hashes between regions
- **Reporting**: Generate detailed replication reports

### 3. Infrastructure Deployment
- **Automated Provisioning**: Deploy Azure Storage accounts with geo-replication
- **Multiple Replication Types**: Support for GRS, RA-GRS, GZRS, RA-GZRS
- **Configuration Management**: Easy configuration through parameters
- **Cleanup Scripts**: Tear down resources when testing is complete

## Prerequisites

- Azure Subscription
- Azure CLI installed and configured (`az --version`)
- Node.js 18+ or Python 3.8+ (for data generation and monitoring scripts)
- Bicep (included with Azure CLI 2.20.0+)

## Quick Start

### 1. Deploy Infrastructure

```bash
cd infra

# Configure your parameters (set unique storage account name)
cp parameters.example.json parameters.json
nano parameters.json  # Edit with your settings

# Deploy using Bicep
./deploy.sh

# Load the deployment outputs into your environment
source deployment-outputs.env
```

The deployment script will:
- Create an Azure Resource Group
- Deploy a geo-replicated storage account (RA-RAGRS by default)
- Create test containers
- Configure blob versioning, change feed, and diagnostics
- Save connection details for use by other tools

### 2. Generate Test Data

```bash
cd src/data-generator

# Generate 100MB text file
node generate.js --type text --size 100MB --output test-data.txt
# OR using Python
python generate_data.py --type text --size 100MB --output test-data.txt

# Generate 500MB binary file
node generate.js --type binary --size 500MB --output test-data.bin
```

### 3. Upload and Monitor Replication

```bash
cd src/replication-monitor

# Upload data and start monitoring (Node.js)
node monitor.js \
  --file ../../test-data.txt \
  --container test-data

# OR using Python
python monitor_replication.py \
  --file ../../test-data.txt \
  --container test-data
```

The monitor will automatically use the connection details from your deployment.

## Configuration

### Storage Account Setup

The Bicep infrastructure (`infra/main.bicep`) supports the following replication types:

| Type | Description | Read Access to Secondary | Best For |
|------|-------------|-------------------------|----------|
| **Standard_GRS** | Geo-Redundant Storage | ❌ No | Basic replication testing |
| **Standard_RAGRS** | Read-Access GRS | ✅ Yes | **Recommended for this project** |
| **Standard_GZRS** | Geo-Zone-Redundant | ❌ No | Zone + geo redundancy |
| **Standard_RAGZRS** | Read-Access GZRS | ✅ Yes | Maximum availability testing |

**Important**: For replication monitoring, you must use **RA-RAGRS** or **RA-GZRS** to enable read access to the secondary region.

### Environment Variables

After running `./infra/deploy.sh`, load the generated configuration:

```bash
source infra/deployment-outputs.env
```

This sets:
- `AZURE_RESOURCE_GROUP` - Your resource group name
- `AZURE_STORAGE_ACCOUNT` - Storage account name
- `AZURE_PRIMARY_LOCATION` - Primary region
- `AZURE_SECONDARY_LOCATION` - Secondary (paired) region
- `AZURE_PRIMARY_ENDPOINT` - Primary blob endpoint URL
- `AZURE_SECONDARY_ENDPOINT` - Secondary blob endpoint URL

## Testing Scenarios

### Scenario 1: Basic Replication
Test standard geo-replication from primary to secondary region.

### Scenario 2: Replication Lag Under Load
Measure replication lag when uploading multiple large files simultaneously.

### Scenario 3: Failover Behavior
Test read access to secondary region during primary region outage.

### Scenario 4: Storage Actions
Validate Azure Storage Actions like lifecycle management and blob tiering.

## Monitoring Metrics

The replication monitor tracks:
- **Upload Time**: Time to upload to primary region
- **Detection Time**: Time until blob appears in secondary region
- **Replication Lag**: Delta between upload and secondary availability
- **Data Integrity**: Checksum verification between regions
- **Consistency**: Metadata and property comparison

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file for details

## Troubleshooting

### Common Issues

**Issue**: Secondary region shows "not found" error
- **Solution**: Ensure you're using RA-RAGRS or RA-GZRS for read access to secondary. Check `parameters.json` before deployment.

**Issue**: Replication lag is very high
- **Solution**: This is normal for large files; Azure replication is eventually consistent. Typical lag: 15 minutes to 1 hour depending on file size and region load.

**Issue**: Authentication errors
- **Solution**: Run `az login` and ensure you have proper permissions (Contributor or Owner role on the subscription).

**Issue**: Storage account name already taken
- **Solution**: Storage account names must be globally unique (3-24 lowercase alphanumeric characters). Choose a different name in `parameters.json`.

**Issue**: Deployment validation fails
- **Solution**: Check that all required parameters are set correctly. Run `az deployment group validate` to see detailed error messages.

## Resources

- [Azure Storage Replication Documentation](https://docs.microsoft.com/azure/storage/common/storage-redundancy)
- [Azure Storage Actions](https://docs.microsoft.com/azure/storage/blobs/storage-blob-storage-tiers)
- [Azure Blob Storage SDK](https://docs.microsoft.com/azure/storage/blobs/storage-quickstart-blobs-python)

## Implementation Status

### ✅ Completed
- [x] Infrastructure deployment with Bicep
- [x] Automated deployment scripts
- [x] Comprehensive documentation
- [x] Support for all geo-replication types
- [x] Diagnostic logging and monitoring setup

### 🚧 In Progress
- [ ] Data generator (text and binary)
- [ ] Replication monitoring tool
- [ ] Azure Storage Actions testing

### 📋 Planned
- [ ] Web dashboard for real-time monitoring
- [ ] Automated test scenarios
- [ ] Performance benchmarking suite
- [ ] Multi-region replication testing
- [ ] Support for Azure Data Lake Storage Gen2
- [ ] Prometheus metrics export

## Technology Stack

- **Infrastructure**: Bicep + Azure CLI
- **Data Generator**: Node.js or Python (TBD)
- **Replication Monitor**: Node.js or Python (TBD)
- **Cloud Provider**: Microsoft Azure
- **Storage**: Azure Blob Storage with geo-replication

## Cleanup

To remove all deployed resources:

```bash
cd infra
./destroy.sh
```

**⚠️ Warning**: This will permanently delete all resources and data!

## Authors

Data-Grav testing framework for Azure Storage replication scenarios.

---

**Note**: This tool is for testing purposes. Ensure you monitor costs when generating and storing large amounts of data in Azure.