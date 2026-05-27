output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "public_subnet_id" {
  value = azurerm_subnet.public.id
}

output "private_subnet_id" {
  value = azurerm_subnet.private.id
}

# output "app_url" {
#   value = azurerm_linux_web_app.main.default_hostname
# }

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}
