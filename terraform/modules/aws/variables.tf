variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "ec2_ami" {
  type    = string
  # ubuntu 22.04 LTS in eu-west-2
  default = "ami-0eb260c4d5475b901"
}

variable "ec2_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}
