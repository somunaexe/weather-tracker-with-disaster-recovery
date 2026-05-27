output "aws_vpn_gateway_id" {
  value = aws_vpn_gateway.main.id
}

output "aws_vpn_tunnel1_address" {
  value = aws_vpn_connection.main.tunnel1_address
}

output "azure_vpn_gateway_ip" {
  value = azurerm_public_ip.vpn_gateway.ip_address
}
