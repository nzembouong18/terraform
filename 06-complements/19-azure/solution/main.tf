terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend distant Azure (à activer en équipe) :
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstatexxxx"
  #   container_name       = "tfstate"
  #   key                  = "formation/dev.tfstate"
  #   use_oidc             = true
  # }
}

provider "azurerm" {
  features {}
  # subscription_id est obligatoire depuis azurerm 4.x : variable d'env ARM_SUBSCRIPTION_ID
  # ou ci-dessous. skip_provider_registration évite les droits excessifs.
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  type        = string
  description = "ID de la souscription Azure"
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "location" {
  type    = string
  default = "francecentral"
}

variable "nom" {
  type        = string
  description = "Préfixe de nommage (3 à 12 caractères a-z0-9)"
  default     = "formation"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.nom))
    error_message = "3 à 12 caractères alphanumériques minuscules."
  }
}

variable "subnets" {
  type = map(object({
    cidr        = string
    ouvrir_http = optional(bool, false)
  }))
  default = {
    web  = { cidr = "10.30.1.0/24", ouvrir_http = true }
    data = { cidr = "10.30.2.0/24" }
  }
}

locals {
  tags = {
    projet       = "formation-terraform"
    gere_par     = "terraform"
    proprietaire = "equipe-plateforme"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.nom}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.nom}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each             = var.subnets
  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]
}

resource "azurerm_network_security_group" "this" {
  for_each            = var.subnets
  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  dynamic "security_rule" {
    for_each = each.value.ouvrir_http ? [80, 443] : []
    content {
      name                       = "autoriser-${security_rule.value}"
      priority                   = 100 + security_rule.value
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# Nom de compte de stockage : 3-24 caractères, minuscules/chiffres, UNIQUE mondialement
resource "random_string" "suffixe" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "this" {
  name                            = "st${var.nom}${random_string.suffixe.result}"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true
  }
}

output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "subnets" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}

output "storage_account" {
  value = azurerm_storage_account.this.name
}
