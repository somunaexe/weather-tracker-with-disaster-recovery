output "vpc_id" {
  value = module.aws.vpc_id
}

output "public_subnet_id" {
  value = module.aws.public_subnet_id
}

output "private_subnet_id" {
  value = module.aws.private_subnet_id
}

output "ec2_public_ip" {
  value = module.aws.ec2_public_ip
}

output "s3_bucket_name" {
  value = module.aws.s3_bucket_name
}

output "azure_resource_group" {
  value = module.azure.resource_group_name
}

output "azure_vnet_id" {
  value = module.azure.vnet_id
}

# output "azure_app_url" {
#   value = module.azure.app_url
# }

output "azure_storage_account" {
  value = module.azure.storage_account_name
}
