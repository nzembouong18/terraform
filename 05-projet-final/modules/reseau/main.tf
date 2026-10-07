terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0"
    }
  }
}

variable "nom" {
  type = string
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "CIDR invalide."
  }
}

variable "nb_zones" {
  type    = number
  default = 2

  validation {
    condition     = var.nb_zones >= 2 && var.nb_zones <= 3
    error_message = "Entre 2 et 3 zones de disponibilité."
  }
}

variable "nat_gateway_unique" {
  description = "true = 1 seule NAT (économique, dev) ; false = 1 par zone (haute dispo, prod)"
  type        = bool
  default     = true
}

data "aws_availability_zones" "dispo" {
  state = "available"
}

locals {
  zones = slice(data.aws_availability_zones.dispo.names, 0, var.nb_zones)
  # sous-réseaux publics : 10.0.0.0/24, 10.0.1.0/24... privés : 10.0.10.0/24...
  publics   = { for i, z in local.zones : z => cidrsubnet(var.cidr, 8, i) }
  prives    = { for i, z in local.zones : z => cidrsubnet(var.cidr, 8, i + 10) }
  nat_zones = var.nat_gateway_unique ? [local.zones[0]] : local.zones
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  tags                 = { Name = var.nom }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.nom }
}

resource "aws_subnet" "public" {
  for_each                = local.publics
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.nom}-public-${each.key}" }
}

resource "aws_subnet" "prive" {
  for_each          = local.prives
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.nom}-prive-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.nom}-public" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_zones)
  domain   = "vpc"
  tags     = { Name = "${var.nom}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each      = toset(local.nat_zones)
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = { Name = "${var.nom}-${each.key}" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "prive" {
  for_each = local.prives
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    # zone avec sa propre NAT sinon la NAT unique
    nat_gateway_id = aws_nat_gateway.this[contains(local.nat_zones, each.key) ? each.key : local.nat_zones[0]].id
  }
  tags = { Name = "${var.nom}-prive-${each.key}" }
}

resource "aws_route_table_association" "prive" {
  for_each       = aws_subnet.prive
  subnet_id      = each.value.id
  route_table_id = aws_route_table.prive[each.key].id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnets_publics" {
  value = [for s in aws_subnet.public : s.id]
}

output "subnets_prives" {
  value = [for s in aws_subnet.prive : s.id]
}
