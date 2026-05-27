variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_vpc_id" {
  type = string
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aws_route_table_id" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "azure_resource_group" {
  type = string
}

variable "azure_vnet_name" {
  type = string
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "azure_vpn_gateway_ip" {
  type        = string
  description = "Public IP of the Azure VPN gateway - known after Azure VPN gateway is created"
}

variable "vpn_shared_key" {
  type        = string
  description = "Shared secret for the VPN tunnel - keep this secret"
}
