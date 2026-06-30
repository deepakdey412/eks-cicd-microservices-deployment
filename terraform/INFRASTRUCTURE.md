# Terraform Infrastructure Configuration

This directory contains all Terraform code to provision the complete AWS infrastructure for running microservices on Amazon EKS.

## What This Does

Terraform provisions and manages the entire AWS infrastructure as code. When you run `terraform apply`, it creates:

### Core Infrastructure
- **VPC** (Virtual Private Cloud)
  - CIDR: 10.0.0.0/16
  - 2 Public subnets (10.0.1.0/24, 10.0.2.0/24) - for Load Balancer
  - 2 Private subnets (10.0.3.0/24, 10.0.4.0/24) - for EKS worker nodes
  - 1 Internet Gateway - for public subnet internet access
  - 1 NAT Gateway - for private subnet outbound internet access
  - Route tables configured for proper traffic routing

### EKS Cluster
- **Cluster Name**: ms-eks
- **Kubernetes Version**: 1.31
- **Control Plane**: Fully managed by AWS
- **Node Group**: 
  - 2 worker nodes (min: 1, max: 3)
  - Instance type: t3.small (2 vCPU, 2GB RAM)
  - On-demand pricing
  - Auto-scaling enabled

### Networking & Security
- **Security Groups**:
  - Cluster security group (managed by EKS)
  - Node security group with self-referencing rule for pod-to-pod communication
  
- **IAM Roles**:
  - EKS cluster role
  - Node group role
  - OIDC provider for service accounts
  - ALB controller service account role

### Add-ons
- **AWS Load Balancer Controller**:
  - Deployed via Helm
  - Manages Application Load Balancers
  - Creates ALB based on Kubernetes Ingress resources
  - Handles SSL termination and routing rules

- **CoreDNS**: For internal service discovery

## File Structure

```
terraform/
├── vpc.tf                  # VPC, subnets, route tables, NAT gateway
├── eks.tf                  # EKS cluster and node group
├── alb-controller.tf       # AWS Load Balancer Controller installation
├── helm-deployments.tf     # (Optional) Initial Helm deployments
├── providers.tf            # AWS and Kubernetes provider configuration
├── variables.tf            # Input variables and defaults
├── outputs.tf              # Output values after deployment
└── README.md              # This file
```

## Prerequisites

1. **AWS CLI** configured with credentials:
   ```bash
   aws configure
   ```

2. **Terraform** installed (v1.0+):
   ```bash
   terraform version
   ```

3. **kubectl** installed:
   ```bash
   kubectl version --client
   ```

## Usage

### Quick Deploy (Recommended)

From project root:
```bash
./scripts/infra-up.sh
```

### Manual Deploy

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (downloads providers)
terraform init

# Review what will be created
terraform plan

# Create infrastructure
terraform apply

# After completion, configure kubectl
aws eks update-kubeconfig --name ms-eks --region us-east-1
```

### Verify Deployment

```bash
# Check cluster is accessible
kubectl get nodes

# Should show 2 nodes in Ready state
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
```

### Destroy Infrastructure

From project root:
```bash
./scripts/infra-down.sh
```

Or manually:
```bash
cd terraform
terraform destroy
```

## Configuration

### Key Variables

Edit `variables.tf` to customize (defaults work for most cases):

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | "ms-eks" | EKS cluster name |
| `aws_region` | "us-east-1" | AWS region |
| `instance_type` | "t3.small" | Worker node instance type |
| `desired_capacity` | 2 | Number of worker nodes |
| `min_size` | 1 | Minimum nodes for auto-scaling |
| `max_size` | 3 | Maximum nodes for auto-scaling |

### Cost Optimization Tips

1. **Use t3.small instances** - Free tier eligible (750 hours/month for 12 months)
2. **Single NAT Gateway** - Saves ~$32/month vs one per AZ
3. **On-demand instances** - Predictable pricing, can switch to Spot for 70% savings
4. **Destroy when not in use** - Run `./scripts/infra-down.sh` to avoid charges

**Estimated Monthly Cost** (without free tier):
- EKS cluster: ~$73/month
- EC2 t3.small (2 nodes): ~$30/month
- NAT Gateway: ~$32/month
- ALB: ~$16/month
- **Total**: ~$151/month

## How Terraform Works with This Project

### Infrastructure Layer (Terraform)
Terraform creates the **foundation**:
- AWS resources (VPC, EKS, IAM roles)
- Kubernetes cluster
- Load Balancer Controller

### Application Layer (GitHub Actions + Helm)
GitHub Actions handles **application deployment**:
- Builds Java applications
- Creates Docker images
- Pushes to ECR
- Deploys via Helm to EKS

**Why separate?**
- Infrastructure changes rarely (weeks/months)
- Applications change frequently (daily/hourly)
- Different tools for different jobs

## Terraform State

**State File**: `terraform.tfstate`
- Contains current infrastructure state
- **NOT stored in Git** (excluded via .gitignore)
- Stored locally on your machine

**Important**:
- State file tracks what Terraform created
- Required for updates and destruction
- Keep it safe and backed up

**For Production**: Use remote state:
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Outputs

After successful `terraform apply`, you'll see:

```
Outputs:

cluster_name = "ms-eks"
cluster_endpoint = "https://xxxxx.eks.us-east-1.amazonaws.com"
region = "us-east-1"
vpc_id = "vpc-xxxxx"
```

Use these in your scripts or CI/CD pipelines.

## Troubleshooting

### Issue: "Error creating EKS Cluster"
**Solution**: Check AWS credentials and IAM permissions
```bash
aws sts get-caller-identity
```

### Issue: "NAT Gateway creation timeout"
**Solution**: This is normal, can take 5-10 minutes. Wait or increase timeout.

### Issue: "kubectl can't connect to cluster"
**Solution**: Update kubeconfig
```bash
aws eks update-kubeconfig --name ms-eks --region us-east-1
```

### Issue: "Terraform state locked"
**Solution**: Another terraform process is running. Wait or force unlock (careful):
```bash
terraform force-unlock <lock-id>
```

## Next Steps

After infrastructure is ready:

1. **Verify cluster**: `kubectl get nodes`
2. **Push code**: GitHub Actions will deploy applications automatically
3. **Get ALB URL**: `kubectl get ingress -n default`
4. **Test services**: Use ALB URL to access applications

## Learn More

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
