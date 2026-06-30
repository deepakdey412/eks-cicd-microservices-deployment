# Project Summary

## Overview
Microservices architecture on Amazon EKS demonstrating service-to-service communication, automated CI/CD, and infrastructure as code.

## Architecture

### Services

**product-service** (Java/Spring Boot)
- Creates and manages products
- Sends items to order-service for storage
- Communicates with order-service via REST API
- Endpoints: `/hello`, `/hello/create-item`, `/hello/items`

**order-service** (Java/Spring Boot)
- Stores items in-memory (ConcurrentHashMap)
- Receives items from product-service
- Serves web UI
- Endpoints: `/`, `/api/items`, `/send-to-hello`, `/receive-message`

### Technology Stack

| Layer | Technology |
|-------|------------|
| **Language** | Java 17 |
| **Framework** | Spring Boot 3.2.5 |
| **Build** | Maven |
| **Container** | Docker |
| **Registry** | Amazon ECR |
| **Orchestration** | Kubernetes (EKS 1.31) |
| **Deployment** | Helm Charts |
| **Infrastructure** | Terraform |
| **CI/CD** | GitHub Actions |
| **Load Balancer** | AWS ALB |
| **Networking** | VPC, NAT Gateway |

## How It Works

### 1. Infrastructure Layer (Terraform)
```
terraform/
├── vpc.tf           # Network: VPC, subnets, NAT, IGW
├── eks.tf           # Kubernetes: EKS cluster, node group
├── alb-controller.tf # Load balancing: ALB Controller
└── providers.tf     # AWS configuration
```

**Creates**:
- VPC (10.0.0.0/16) with 2 public + 2 private subnets
- EKS cluster with 2 t3.small nodes
- AWS Load Balancer Controller (Helm)
- IAM roles and security groups

### 2. Application Layer (GitHub Actions + Helm)

**Build Pipeline** (.github/workflows/build-and-deploy.yml):
1. Compile Java with Maven
2. Build Docker images
3. Push to Amazon ECR
4. Deploy via Helm

**Helm Chart** (helm-chart/springboot/):
- Single reusable template
- Configurable via values
- Creates: Deployment, Service, Ingress, HPA

### 3. Network Flow

#### External Traffic (User → Services)
```
Internet
   ↓
AWS Application Load Balancer
   ↓
ALB Ingress Rules (priority-based):
   ├─ Priority 1: /hello/*  → product-service
   └─ Priority 2: /*        → order-service
   ↓
Kubernetes Service (ClusterIP)
   ↓
Pods (2 replicas each)
```

#### Internal Traffic (Service-to-Service)
```
product-service → http://client.default.svc.cluster.local
order-service   → http://hello.default.svc.cluster.local
```

**Kubernetes DNS Pattern**: `<service-name>.<namespace>.svc.cluster.local`

### 4. Data Flow

#### Item Creation Flow
```
1. User → POST /hello/create-item (product-service)
2. product-service → POST /api/items (order-service)
3. order-service → Store in ConcurrentHashMap
4. order-service → Return success
5. product-service → Return result to user
```

#### Message Exchange Flow
```
Bi-directional:
- order-service → POST /hello/receive-message
- product-service → POST /receive-message

Both services can send and receive messages
```

## Deployment Workflow

### One-Time Setup (Infrastructure)
```bash
./scripts/infra-up.sh      # Deploy AWS resources
./scripts/verify-infra.sh  # Verify deployment
```

### Continuous Deployment (Applications)
```bash
git push origin main       # Triggers GitHub Actions
```

**GitHub Actions Does**:
1. Build both services (parallel)
2. Create Docker images
3. Push to ECR
4. Deploy to EKS via Helm
5. Wait for pods to be ready

### Cleanup
```bash
./scripts/infra-down.sh    # Destroy all AWS resources
```

## Security

### Network Security
- Private subnets for worker nodes
- NAT Gateway for outbound internet
- Security groups with self-referencing rules (pod-to-pod)
- ALB in public subnets only

### IAM & RBAC
- EKS cluster role with minimal permissions
- Node group role for EC2 instances
- OIDC provider for service accounts (IRSA)
- ALB Controller service account with IAM role

### Container Security
- Images from trusted base (Eclipse Temurin 17)
- No root user in containers
- Health checks and liveness probes

## Scaling

### Horizontal Pod Autoscaler (HPA)
- Min replicas: 2
- Max replicas: 10
- Target CPU: 50%

### Cluster Autoscaler
- Node group auto-scaling: 1-3 nodes
- Scales based on pod resource requests

## Storage

**In-Memory (ConcurrentHashMap)**:
- Fast access
- Lost on pod restart
- Suitable for demo/cache

**For Production**: Use Amazon RDS, DynamoDB, or ElastiCache

## Monitoring & Observability

**Built-in**:
- Kubernetes health checks
- ALB health checks
- CloudWatch logs (auto-collected)

**Recommended**:
- Prometheus + Grafana (metrics)
- ELK Stack (centralized logging)
- AWS X-Ray (distributed tracing)

## Cost Breakdown

**Monthly Estimate** (us-east-1, no free tier):

| Resource | Cost |
|----------|------|
| EKS Control Plane | $73 |
| EC2 (2x t3.small) | $30 |
| NAT Gateway | $32 |
| Application Load Balancer | $16 |
| Data Transfer | ~$5 |
| **Total** | **~$156/month** |

**Savings**:
- Use t3.small (free tier eligible)
- Single NAT Gateway (vs one per AZ)
- Destroy when not in use

## Links

- **Quick Start**: [QUICKSTART.md](../QUICKSTART.md)
- **Infrastructure Details**: [INFRASTRUCTURE.md](INFRASTRUCTURE.md) (this file)
- **Main README**: [README.md](../README.md)
