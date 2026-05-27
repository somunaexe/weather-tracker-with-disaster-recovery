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
  source       = "../modules/azure"
  project_name = var.project_name
  environment  = var.environment
  azure_region = var.azure_region
}
