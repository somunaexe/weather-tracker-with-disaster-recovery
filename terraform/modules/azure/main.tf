# Resource group - everything in Azure must belong to one
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.azure_region

#  lifecycle {
#    prevent_destroy = true
#  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Virtual network - equivalent to AWS VPC
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Public subnet
resource "azurerm_subnet" "public" {
  name                 = "${var.project_name}-public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Private subnet
resource "azurerm_subnet" "private" {
  name                 = "${var.project_name}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_cidr]
}

# Network security group - equivalent to AWS security group
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow HTTP
  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS
  security_rule {
    name                       = "allow-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# App service plan - defines the compute resources for the app
#  resource "azurerm_service_plan" "main" {
#   name                = "${var.project_name}-asp"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   os_type             = "Linux"
#   sku_name            = "F1"
# 
#   tags = {
#     Environment = var.environment
#     Project     = var.project_name
#   }
# }
# 
# # App service - runs the weather tracker app
#  resource "azurerm_linux_web_app" "main" {
#   name                = "${var.project_name}-app"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   service_plan_id     = azurerm_service_plan.main.id
# 
#  site_config {
#     always_on = false # always_on not supported on free tier F1
#   }
# 
#  lifecycle {
#    prevent_destroy = true
#  }
# 
#   tags = {
#     Environment = var.environment
#     Project     = var.project_name
#   }
# }

# Storage account - azure equivalent of S3
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.project_name, "-", "")}exe"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

#  lifecycle {
#    prevent_destroy = true
#  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Blob container - equivalent to S3 bucket folder
resource "azurerm_storage_container" "weather_data" {
  name                  = "weather-data"
  storage_account_name    = azurerm_storage_account.main.name
  container_access_type = "private"
}
