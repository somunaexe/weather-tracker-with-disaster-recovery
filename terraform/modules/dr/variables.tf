variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# the public IP of my EC2 - health check pings this
variable "ec2_public_ip" {
  type        = string
  description = "Public IP of the AWS EC2 instance"
}

# needed so CloudWatch knows which EC2 to watch
variable "ec2_instance_id" {
  type        = string
  description = "Instance ID of the AWS EC2"
}

# Azure takes over at this URL when AWS goes down
variable "azure_app_url" {
  type        = string
  description = "URL of the Azure App Service - used as failover target"
}

# the domain my app will be accessible at
variable "domain_name" {
  type        = string
  description = "Domain name for the weather tracker app"
}
