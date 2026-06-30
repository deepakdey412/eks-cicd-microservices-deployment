# Microservices on Amazon EKS

Production-ready microservices demonstrating service communication, automated CI/CD, and infrastructure as code on AWS.

## Quick Overview

Two Spring Boot services on Amazon EKS:
- **product-service**: Creates and manages products
- **order-service**: Stores orders and serves web UI

Both communicate internally via Kubernetes DNS and are exposed via AWS Application Load Balancer.

## Get Started

```bash
# 1. Deploy infrastructure
./scripts/infra-up.sh

# 2. Verify deployment
./scripts/verify-infra.sh

# 3. Push code (triggers auto-deployment)
git push origin main

# 4. Access application
kubectl get ingress -n default
# Open http://<ALB-DNS>/ in browser
```

## Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Step-by-step setup guide (15 minutes) |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Architecture, flow, and how everything works |
| [terraform/INFRASTRUCTURE.md](terraform/INFRASTRUCTURE.md) | Infrastructure details and Terraform usage |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions (CI/CD)                                     │
│  ├─ Build: Maven → Docker → ECR                            │
│  └─ Deploy: Helm → EKS                                      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  AWS Infrastructure (Terraform)                             │
│  ├─ VPC: Public/Private Subnets, NAT Gateway                │
│  ├─ EKS: Kubernetes 1.31, 2x t3.small nodes                │
│  └─ ALB: Application Load Balancer + Controller             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Kubernetes Workloads (Helm)                                │
│  ├─ product-service: 2 replicas                             │
│  ├─ order-service: 2 replicas                               │
│  └─ Services: Internal DNS + ALB Ingress                    │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

**Backend**: Java 17, Spring Boot 3.2.5, Maven  
**Infrastructure**: AWS EKS, VPC, ALB, Terraform  
**CI/CD**: GitHub Actions, Helm Charts  
**Container**: Docker, Amazon ECR

## Repository Structure

```
.
├── microservices/
│   ├── product-service/      # Java Spring Boot app
│   └── order-service/        # Java Spring Boot app
├── terraform/                # Infrastructure as Code
│   ├── vpc.tf               # Networking
│   ├── eks.tf               # Kubernetes cluster
│   └── INFRASTRUCTURE.md    # Detailed docs
├── helm-chart/springboot/   # Kubernetes deployment template
├── .github/workflows/       # CI/CD pipeline
├── scripts/
│   ├── infra-up.sh         # Deploy infrastructure
│   ├── infra-down.sh       # Destroy infrastructure
│   └── verify-infra.sh     # Verify deployment
└── docs/
    ├── QUICKSTART.md       # Setup guide
    └── PROJECT_SUMMARY.md  # Architecture docs
```

## Key Features

✅ **Automated CI/CD**: Push code → auto-deploy  
✅ **Service Communication**: Internal DNS + REST APIs  
✅ **Auto-scaling**: HPA for pods, ASG for nodes  
✅ **Load Balancing**: AWS ALB with path-based routing  
✅ **Infrastructure as Code**: Complete Terraform setup  
✅ **Production-ready**: Health checks, logging, monitoring

## Common Commands

### Infrastructure
```bash
./scripts/infra-up.sh         # Create infrastructure
./scripts/verify-infra.sh     # Check status
./scripts/infra-down.sh       # Destroy everything
```

### Kubernetes
```bash
kubectl get pods -n default                    # List pods
kubectl logs <pod-name> -n default --tail=50   # View logs
kubectl get ingress -n default                 # Get ALB URL
helm list -n default                           # List releases
```

### Testing
```bash
ALB_URL=$(kubectl get ingress -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Create item
curl -X POST http://$ALB_URL/hello/create-item \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"High performance","price":999}'

# Get items
curl http://$ALB_URL/api/items
```

## Prerequisites

- AWS Account + CLI configured (`aws configure`)
- kubectl installed
- Terraform installed
- GitHub repo with secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

## Cleanup

Destroy all resources to avoid charges:

```bash
./scripts/infra-down.sh
```

**Cost**: ~$5/day running, $0 when destroyed

## Troubleshooting

Run verification script:
```bash
./scripts/verify-infra.sh
```

Common issues:
- **Pods not starting**: Check logs with `kubectl logs <pod-name>`
- **ALB not created**: Check ALB controller logs
- **Can't connect**: Verify security groups and NAT Gateway

See [QUICKSTART.md](QUICKSTART.md) for detailed troubleshooting.

## Support

- **Setup Help**: See [QUICKSTART.md](QUICKSTART.md)
- **Architecture Questions**: See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- **Infrastructure Issues**: See [terraform/INFRASTRUCTURE.md](terraform/INFRASTRUCTURE.md)
- **Issues**: [GitHub Issues](https://github.com/deepakdey412/EKS-project/issues)

## License

MIT License - Open source and free to use.

---

**Quick Links**: [Setup Guide](QUICKSTART.md) • [Architecture](PROJECT_SUMMARY.md) • [Infrastructure](terraform/INFRASTRUCTURE.md)
