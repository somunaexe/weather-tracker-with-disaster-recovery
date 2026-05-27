terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "weather-tracker-tfstate"
    key          = "global/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

module "aws" {
  source       = "../modules/aws"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  key_name     = var.key_name
}

module "azure" {
  source        = "../modules/azure"
  project_name  = var.project_name
  environment   = var.environment
  azure_region  = var.azure_region
}

module "networking" {
  source               = "../modules/networking"
  project_name         = var.project_name
  environment          = var.environment
  aws_vpc_id           = module.aws.vpc_id
  aws_route_table_id   = module.aws.public_route_table_id
  azure_region         = var.azure_region
  azure_resource_group = module.azure.resource_group_name
  azure_vnet_name      = module.azure.vnet_name
  azure_vpn_gateway_ip = module.networking.azure_vpn_gateway_ip
  vpn_shared_key       = var.vpn_shared_key
}

module "dr" {
  source          = "../modules/dr"
  project_name    = var.project_name
  environment     = var.environment
  ec2_public_ip   = module.aws.ec2_public_ip
  ec2_instance_id = module.aws.ec2_instance_id
  azure_app_url   = "placeholder.azurewebsites.net"
  domain_name     = var.domain_name
}
