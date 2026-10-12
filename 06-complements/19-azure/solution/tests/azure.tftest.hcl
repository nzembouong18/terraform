# Tests sans abonnement Azure : provider simulé
mock_provider "azurerm" {
  # Le provider valide le format des identifiants Azure : on fournit des IDs réalistes
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg"
    }
  }
}
mock_provider "random" {}

run "un_subnet_par_entree_et_http_sur_web_seulement" {
  command = apply

  assert {
    condition     = length(azurerm_subnet.this) == 2
    error_message = "2 sous-réseaux attendus."
  }

  assert {
    condition     = length(azurerm_network_security_group.this["web"].security_rule) == 2
    error_message = "Le NSG web doit ouvrir 80 et 443."
  }

  assert {
    condition     = length(azurerm_network_security_group.this["data"].security_rule) == 0
    error_message = "Le NSG data ne doit rien ouvrir depuis Internet."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "TLS 1.2 minimum."
  }
}

run "nom_invalide" {
  command = plan
  variables {
    nom = "Nom_Invalide"
  }
  expect_failures = [var.nom]
}
