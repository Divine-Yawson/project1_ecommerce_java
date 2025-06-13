variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ecommerce"
}
variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ecommerce-eks"
}
variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.27"
}
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}