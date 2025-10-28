// Main Bicep template for Azure Storage replication testing
targetScope = 'resourceGroup'

@description('Environment name (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Primary Azure region for storage account')
param primaryLocation string = resourceGroup().location

@description('Storage account name (must be globally unique, 3-24 lowercase alphanumeric characters)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Storage account replication type')
@allowed([
  'Standard_GRS'     // Geo-Redundant Storage
  'Standard_RAGRS'   // Read-Access Geo-Redundant Storage
  'Standard_GZRS'    // Geo-Zone-Redundant Storage
  'Standard_RAGZRS'  // Read-Access Geo-Zone-Redundant Storage
])
param replicationType string = 'Standard_RAGRS'

@description('Enable blob versioning')
param enableVersioning bool = true

@description('Enable change feed for blob storage')
param enableChangeFeed bool = true

@description('Container names to create')
param containerNames array = [
  'test-data'
  'replication-test'
  'performance-test'
]

@description('Enable blob soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention days')
@minValue(1)
@maxValue(365)
param softDeleteRetentionDays int = 7

@description('Tags to apply to resources')
param tags object = {
  Project: 'data-grav'
  Purpose: 'replication-testing'
  Environment: environment
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: primaryLocation
  tags: tags
  sku: {
    name: replicationType
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob Service configuration
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: enableSoftDelete
      days: softDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: enableSoftDelete
      days: softDeleteRetentionDays
    }
    changeFeed: {
      enabled: enableChangeFeed
      retentionInDays: 7
    }
    isVersioningEnabled: enableVersioning
    cors: {
      corsRules: []
    }
  }
}

// Create containers
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

// Note: Diagnostic settings commented out as they require a Log Analytics workspace or storage account sink
// You can enable these manually in Azure Portal or add a Log Analytics workspace to this template

// // Diagnostic settings for monitoring
// resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   scope: storageAccount
//   name: '${storageAccountName}-diagnostics'
//   properties: {
//     metrics: [
//       {
//         category: 'Transaction'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//       {
//         category: 'Capacity'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//     ]
//   }
// }

// // Blob service diagnostic settings
// resource blobDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   scope: blobService
//   name: '${storageAccountName}-blob-diagnostics'
//   properties: {
//     logs: [
//       {
//         category: 'StorageRead'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//       {
//         category: 'StorageWrite'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//       {
//         category: 'StorageDelete'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//     ]
//     metrics: [
//       {
//         category: 'Transaction'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//     ]
//   }
// }

// Outputs
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoint string = storageAccount.properties.primaryEndpoints.blob
output secondaryEndpoint string = storageAccount.properties.secondaryEndpoints.blob
output primaryLocation string = storageAccount.location
output secondaryLocation string = storageAccount.properties.secondaryLocation
output replicationType string = replicationType
output containerNames array = [for (name, i) in containerNames: containers[i].name]
// Connection string contains secrets - retrieve it using: az storage account show-connection-string
// output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
