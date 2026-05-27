# ─── AWS SIDE ───────────────────────────────────────────

# Virtual private gateway - AWS side of the VPN tunnel
resource "aws_vpn_gateway" "main" {
  vpc_id = var.aws_vpc_id

  tags = {
    Name        = "${var.project_name}-vgw"
    Environment = var.environment
  }
}

# Customer gateway - tells AWS where the Azure VPN gateway is
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65000
  ip_address = var.azure_vpn_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name        = "${var.project_name}-cgw"
    Environment = var.environment
  }
}

# VPN connection - the actual tunnel between AWS and Azure
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.azure.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name        = "${var.project_name}-vpn"
    Environment = var.environment
  }
}

# Route that sends Azure-bound traffic through the VPN
resource "aws_vpn_connection_route" "azure" {
  destination_cidr_block = var.azure_vnet_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

# Attach the VPN gateway to the VPC route table
resource "aws_vpn_gateway_route_propagation" "main" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = var.aws_route_table_id
}

# ─── AZURE SIDE ─────────────────────────────────────────

# Public IP for the Azure VPN gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.project_name}-vpn-pip"
  location            = var.azure_region
  resource_group_name = var.azure_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  zones = ["1","2","3"]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Subnet required by Azure specifically for VPN gateways
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.azure_resource_group
  virtual_network_name = var.azure_vnet_name
  address_prefixes     = ["10.1.255.0/27"]
}

# Azure VPN gateway
resource "azurerm_virtual_network_gateway" "main" {
  name                = "${var.project_name}-vng"
  location            = var.azure_region
  resource_group_name = var.azure_resource_group
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"
  active_active       = false
  enable_bgp          = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Tells Azure where the AWS VPN gateway is
resource "azurerm_local_network_gateway" "aws" {
  name                = "${var.project_name}-lng"
  location            = var.azure_region
  resource_group_name = var.azure_resource_group
  gateway_address     = aws_vpn_connection.main.tunnel1_address
  address_space       = [var.aws_vpc_cidr]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# The actual VPN connection on the Azure side
resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                = "${var.project_name}-vpn-connection"
  location            = var.azure_region
  resource_group_name = var.azure_resource_group
  type                = "IPsec"

  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id

  shared_key = var.vpn_shared_key

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
