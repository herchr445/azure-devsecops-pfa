terraform {
  backend "azurerm" {
    resource_group_name  = "rg-rami-terraform-backend"
    storage_account_name = "stramitfstate2024pfa"
    container_name       = "tfstate"
    key                  = "rami-pfa.tfstate/terraform.tfstate"
  }
}