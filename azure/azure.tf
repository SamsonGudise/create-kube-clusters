provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=1.36.0"
  #  Subscription ID 
  subscription_id = "${var.subscription_id}"
  alias   = "aks"
}

provider "azuread" {
  alias = "aks"
  version = "=0.3.0"
}