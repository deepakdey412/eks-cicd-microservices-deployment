output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "alb_controller_role_arn" {
  description = "ARN of IAM role for ALB controller"
  value       = module.lb_controller_irsa.iam_role_arn
}

output "hello_service_status" {
  description = "Hello service deployment status"
  value       = helm_release.hello_service.status
}

output "client_service_status" {
  description = "Client service deployment status"
  value       = helm_release.client_service.status
}

output "load_balancer_dns" {
  description = "Get ALB DNS with: kubectl get ingress -n default"
  value       = "Run: kubectl get ingress -n default"
}
