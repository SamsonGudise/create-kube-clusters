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

resource "azurerm_resource_group" "awsdemo" {
  provider = "azurerm.aks"
  name     = "awsdemoRG1"
  location = "East US"
}

resource "azuread_application" "awsdemo" {
  provider                   = "azuread.aks"
  name                       = "awsdemo-app"
  homepage                   = "${var.domain}"
  identifier_uris            = ["${var.domain}"]
  reply_urls                 = ["${var.domain}"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "awsdemo" {
  provider                   = "azuread.aks"
  application_id = "${azuread_application.awsdemo.application_id}"
}

resource "azuread_service_principal_password" "awsdemo" {
  provider                   = "azuread.aks"
  service_principal_id = "${azuread_service_principal.awsdemo.id}"
  value                = "${var.initialpassword}"
  end_date             = "2020-01-01T01:02:03Z"
}

resource "azurerm_kubernetes_cluster" "awsdemo" {
  provider = "azurerm.aks"
  name                = "awsdemoaks1"
  location            = "${azurerm_resource_group.awsdemo.location}"
  resource_group_name = "${azurerm_resource_group.awsdemo.name}"
  dns_prefix          = "awsdemoagent1"

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
    client_id     = "${azuread_application.awsdemo.application_id}"
    client_secret = "${azuread_service_principal_password.awsdemo.value}"
  }

  tags = {
    Environment = "Demo"
  }
}

output "kubeconfig" {
  value = "${azurerm_kubernetes_cluster.awsdemo.kube_config_raw}"
}