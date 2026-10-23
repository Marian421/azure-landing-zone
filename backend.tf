# Where this configuration keeps its state: the container created by bootstrap/.
# A backend block cannot use variables or locals, so the values are written out.

terraform {
  backend "azurerm" {
    resource_group_name  = "tr-lab"   # the resource group that holds the storage account
    storage_account_name = "trlabstate"   # the storage account
    container_name       = "tfstate"   # the container inside it
    key                  = "landing-zone.tfstate"   # the name of the state file (a blob), e.g. "landing-zone.tfstate"
  }
}
