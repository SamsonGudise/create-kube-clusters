variable  domain {
  default = "https://tekgs.io"
}

variable initialpassword {
  default = "thisIsNotGoodIdea"
}

variable machinetype {
  default = "Standard_D1_v2"
}

variable subscription_id {
  default = "3227e46c-57ec-4e2c-8ba4-760eb7d70906"
}

resource "azurerm_resource_group" "awseks-1" {
  provider = "azurerm.aks"
  name     = "awseks-1RG1"
  location = "East US"
}

resource "azuread_application" "awseks-1" {
  provider                   = "azuread.aks"
  name                       = "awseks-1-app"
  homepage                   = "${var.domain}"
  identifier_uris            = ["${var.domain}"]
  reply_urls                 = ["${var.domain}"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "awseks-1" {
  provider                   = "azuread.aks"
  application_id = "${azuread_application.awseks-1.application_id}"
}

resource "azuread_service_principal_password" "awseks-1" {
  provider                   = "azuread.aks"
  service_principal_id = "${azuread_service_principal.awseks-1.id}"
  value                = "${var.initialpassword}"
  end_date             = "2020-01-01T01:02:03Z"
}

resource "azurerm_kubernetes_cluster" "awseks-1" {
  provider = "azurerm.aks"
  name                = "awseks-1aks1"
  location            = "${azurerm_resource_group.awseks-1.location}"
  resource_group_name = "${azurerm_resource_group.awseks-1.name}"
  dns_prefix          = "awseks-1agent1"

  agent_pool_profile {
    name            = "default"
    count           = 1
    vm_size         = "${var.machinetype}"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }

  agent_pool_profile {
    name            = "pool2"
    count           = 1
    vm_size         = "${var.machinetype}"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = "${azuread_application.awseks-1.application_id}"
    client_secret = "${azuread_service_principal_password.awseks-1.value}"
  }

  tags = {
    Environment = "eks-1"
  }
}

output "kubeconfig" {
  value = "${azurerm_kubernetes_cluster.awseks-1.kube_config_raw}"
}