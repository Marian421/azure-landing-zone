locals {
  common_tags = {
    project = "azure-landing-zone"
    purpose = "terraform-state"
    owner   = "marian"
  }
}

# The resource group and the storage account were first created by hand in the portal,
# then adopted into Terraform with `import` blocks (since removed, their job was done).

resource "azurerm_resource_group" "bootstrap" {
  name     = "tr-lab"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "state" {

  lifecycle {
    prevent_destroy = true
  }

  name                     = "trlabstate"
  resource_group_name      = azurerm_resource_group.bootstrap.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = true
  public_network_access_enabled    = true
  allowed_copy_scope               = "AAD"
  cross_tenant_replication_enabled = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

# The "folder" inside the storage account where the state file (a blob) will live.
resource "azurerm_storage_container" "tfstate" {

  lifecycle {
    prevent_destroy = true
  }

  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private" # every request needs credentials
}
