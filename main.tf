provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-hka-data-platform"
  location = "West Europe"
}

variable "admin_password" {
 type = string
}
variable "dataprivacy_password" {
 type = string
}
variable "producer_password" {
 type = string
}
variable "consumer_password" {
 type = string
}
variable "domain_user_principal" {
 type = string
}

# Storage and Ingestion Stage
# Azure Cosmos DB Instances
resource "azurerm_cosmosdb_account" "cosmosdb_postgresql" {
  name                = "hka-data-platform-cosmosdb-pg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  geo_location {
    location          = "germanywestcentral"
    failover_priority = 0
  }
  consistency_policy {
    consistency_level = "Strong"
  }
}

resource "azurerm_cosmosdb_sql_database" "postgresql_db" {
  name                = "postgresql-database"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_postgresql.name
}

resource "azurerm_cosmosdb_sql_container" "postgresql_container" {
  name                = "postgresql-container"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_postgresql.name
  database_name       = azurerm_cosmosdb_sql_database.postgresql_db.name
  partition_key_path  = "/hkadp"
}


resource "azurerm_cosmosdb_account" "cosmosdb_nosql" {
  name                = "hka-data-platform-cosmosdb-nosql"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  geo_location {
    location          = "germanywestcentral"
    failover_priority = 0
  }
  consistency_policy {
    consistency_level = "Strong"
  }
}

resource "azurerm_cosmosdb_sql_database" "nosql_db" {
  name                = "nosql-database"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_nosql.name
}

resource "azurerm_cosmosdb_sql_container" "nosql_container" {
  name                = "nosql-container"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_nosql.name
  database_name       = azurerm_cosmosdb_sql_database.nosql_db.name
  partition_key_path  = "/hkadp"
}

resource "azurerm_cosmosdb_account" "cosmosdb_cassandra" {
  name                = "hka-data-platform-cosmosdb-cassandra"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  capabilities {
    name = "EnableCassandra"
  }
  geo_location {
    location          = "germanywestcentral"
    failover_priority = 0
  }
  consistency_policy {
    consistency_level = "Strong"
  }
}


resource "azurerm_cosmosdb_cassandra_keyspace" "cassandra_keyspace" {
  name                = "cassandra-keyspace"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_cassandra.name
}

resource "azurerm_cosmosdb_account" "cosmosdb_gremlin" {
  name                = "hka-data-platform-cosmosdb-gremlin"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  capabilities {
    name = "EnableGremlin"
  }
  geo_location {
    location          = "germanywestcentral"
    failover_priority = 0
  }
  consistency_policy {
    consistency_level = "Strong"
  }
}

resource "azurerm_cosmosdb_gremlin_database" "gremlin_db" {
  name                = "gremlin-database"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_gremlin.name
}

resource "azurerm_cosmosdb_gremlin_graph" "gremlin_graph" {
  name                = "gremlin-graph"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_gremlin.name
  database_name       = azurerm_cosmosdb_gremlin_database.gremlin_db.name
  partition_key_path  = "/hkadp"
}

# Azure Blob Storage
resource "azurerm_storage_account" "storage_blob" {
  name                = "hkadpstorageblob"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  account_tier        = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "blob_container" {
  name                  = "hka-data-platform-blobcontainer"
  storage_account_name  = azurerm_storage_account.storage_blob.name
  container_access_type = "private"
}


# Transformation Stage: Azure Data Factory
resource "azurerm_data_factory" "data_factory" {
  name                = "hka-data-platform-datafactory"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Serve Stage: Azure Data Lake Storage
resource "azurerm_storage_account" "data_lake" {
  name                     = "hkadpdatalakestorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "data_lake_container" {
  name                  = "hka-data-platform-datalakecontainer"
  storage_account_name  = azurerm_storage_account.data_lake.name
  container_access_type = "private"
}

# LINK STORAGE & INGESTION TO TRANSFORMATION STAGE
# Data Factory Linked Service for Azure Blob Storage
resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob_storage_linked_service" {
  name              = "BlobStorageLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_storage_account.storage_blob.primary_connection_string
}

# Data Factory Linked Service for Cosmos DB (PostgreSQL)
resource "azurerm_data_factory_linked_service_cosmosdb" "cosmosdb_postgresql_linked_service" {
  name              = "CosmosDBPostgreSQLLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_cosmosdb_account.cosmosdb_postgresql.connection_strings[0]
}

# Data Factory Linked Service for Cosmos DB (NoSQL)
resource "azurerm_data_factory_linked_service_cosmosdb" "cosmosdb_nosql_linked_service" {
  name              = "CosmosDBNoSQLLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_cosmosdb_account.cosmosdb_nosql.connection_strings[0]
}

# Data Factory Linked Service for Cosmos DB (Cassandra)
resource "azurerm_data_factory_linked_service_cosmosdb" "cosmosdb_cassandra_linked_service" {
  name              = "CosmosDBCassandraLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_cosmosdb_account.cosmosdb_cassandra.connection_strings[0]
}

# Data Factory Linked Service for Cosmos DB (Gremlin)
resource "azurerm_data_factory_linked_service_cosmosdb" "cosmosdb_gremlin_linked_service" {
  name              = "CosmosDBGremlinLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_cosmosdb_account.cosmosdb_gremlin.connection_strings[0]
}

# Data Factory Linked Service for Serve Data Lake
resource "azurerm_data_factory_linked_service_azure_blob_storage" "serve_data_lake_linked_service" {
  name              = "ServeDataLakeLinkedService"
  data_factory_id   = azurerm_data_factory.data_factory.id
  connection_string = azurerm_storage_account.data_lake.primary_connection_string
}

# ROLES
data "azurerm_subscription" "primary" {
}

resource "azurerm_role_definition" "admin_role" {
  name               = "HKA-DP-ADMINISTRATOR"
  role_definition_id = "2c1e7597-3a58-4e7b-8d44-c3d8b7c9a2f1"
  scope              = data.azurerm_subscription.primary.id
  description        = "Administrator-Rolle für die HKA-Datenplattform."
  permissions {
    actions     = ["*"]
    not_actions = []
  }
  assignable_scopes = [
    data.azurerm_subscription.primary.id,
  ]
}

resource "azurerm_role_definition" "data_privacy_role" {
  name               = "HKA-DP-DATENSCHUTZ"
  role_definition_id = "d6d5a3e8-24e7-4f14-9f6a-79d3eb7126d1"
  scope              = data.azurerm_subscription.primary.id
  description        = "Datenschutz-Rolle für die HKA-Datenplattform."
  permissions {
    actions     = ["*/read"]
    not_actions = []
  }
  assignable_scopes = [
    data.azurerm_subscription.primary.id,
  ]
}

resource "azurerm_role_definition" "producer_role" {
  name               = "HKA-DP-PRODUCER"
  role_definition_id = "b8a7d2d0-2a89-4cfa-8b78-f8b1c9fdb15d"
  scope              = azurerm_resource_group.rg.id
  description        = "Producer-Rolle für die HKA-Datenplattform."
  permissions {
    actions = [
      "Microsoft.DocumentDB/databaseAccounts/read",
      "Microsoft.DocumentDB/databaseAccounts/write",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/read",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/write",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/read",
      "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/write",
      "Microsoft.DocumentDB/cassandraClusters/read",
      "Microsoft.DocumentDB/cassandraClusters/write",
      "Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/read",
      "Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/write",
      "Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/graphs/read",
      "Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/graphs/write",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/blobServices/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action",
      "Microsoft.DataFactory/factories/read",
      "Microsoft.DataFactory/factories/write",
      "Microsoft.DataFactory/factories/pipelines/read",
      "Microsoft.DataFactory/factories/pipelines/write",
      "Microsoft.DataFactory/factories/datasets/read",
      "Microsoft.DataFactory/factories/datasets/write"
    ]
    not_actions = []
  }
  assignable_scopes = [
    azurerm_resource_group.rg.id
  ]
}

resource "azurerm_role_definition" "consumer_role" {
  name               = "HKA-DP-CONSUMER"
  role_definition_id = "e5a2f7c7-1d9d-4e7f-8a3f-0cfb8e5b5e47"
  scope              = azurerm_resource_group.rg.id
  description        = "Consumer-Rolle für die HKA-Datenplattform."
  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      "Microsoft.Storage/storageAccounts/blobServices/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
    ]
    not_actions = []
  }
  assignable_scopes = [
    azurerm_resource_group.rg.id
  ]
}



# Create Azure AD Users
resource "azuread_user" "administrator" {
  user_principal_name = "administrator@${var.domain_user_principal}"
  display_name        = "Administrator HKA-DP"
  mail_nickname       = "Administrator"
  password = var.admin_password
}

resource "azuread_user" "dataprivacy" {
  user_principal_name = "dataprivacy@${var.domain_user_principal}"
  display_name        = "Dataprivacy HKA-DP"
  mail_nickname       = "Dataprivacy"
  password = var.dataprivacy_password
}

resource "azuread_user" "producer" {
  user_principal_name = "producer@${var.domain_user_principal}"
  display_name        = "Producer HKA-DP"
  mail_nickname       = "Producer"
  password = var.producer_password
}

resource "azuread_user" "consumer" {
  user_principal_name = "consumer@${var.domain_user_principal}"
  display_name        = "Consumer HKA-DP"
  mail_nickname       = "Consumer"
  password = var.consumer_password
}

# Assign Roles to Users
resource "azurerm_role_assignment" "admin_assignment" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = azurerm_role_definition.admin_role.name
  principal_id         = azuread_user.administrator.id
}

resource "azurerm_role_assignment" "dataprivacy_assignment" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = azurerm_role_definition.data_privacy_role.name
  principal_id         = azuread_user.dataprivacy.id
}

resource "azurerm_role_assignment" "producer_assignment" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = azurerm_role_definition.producer_role.name
  principal_id         = azuread_user.producer.id
}

resource "azurerm_role_assignment" "consumer_assignment" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = azurerm_role_definition.consumer_role.name
  principal_id         = azuread_user.consumer.id
}

# OUTPUTS
output "cosmosdb_postgresql_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb_postgresql.endpoint
}
output "cosmosdb_nosql_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb_nosql.endpoint
}

output "cosmosdb_cassandra_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb_cassandra.endpoint
}

output "cosmosdb_gremlin_endpoint" {
  value = azurerm_cosmosdb_account.cosmosdb_gremlin.endpoint
}

output "storage_blob_endpoint" {
  value = azurerm_storage_account.storage_blob.primary_blob_endpoint
}

output "data_factory_id" {
  value = azurerm_data_factory.data_factory.id
}

output "data_lake_endpoint" {
  value = azurerm_storage_account.data_lake.primary_blob_endpoint
}