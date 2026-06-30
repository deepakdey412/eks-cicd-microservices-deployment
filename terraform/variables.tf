variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ms-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "hello_service_image" {
  description = "Hello service Docker image"
  type        = string
}

variable "client_service_image" {
  description = "Client service Docker image"
  type        = string
}

variable "hello_service_tag" {
  description = "Hello service image tag"
  type        = string
  default     = "latest"
}

variable "client_service_tag" {
  description = "Client service image tag"
  type        = string
  default     = "latest"
}
