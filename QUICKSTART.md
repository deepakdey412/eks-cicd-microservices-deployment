# Quick Start Guide

Get microservices running on AWS EKS in 15 minutes.

## Prerequisites

✅ AWS Account with CLI configured (`aws configure`)  
✅ kubectl installed  
✅ Terraform installed  
✅ Git repository forked/cloned  
✅ GitHub Secrets configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## Architecture Overview

```
┌─────────────┐         ┌──────────────────┐         ┌──────────────┐
│  Terraform  │ creates │  AWS             │ runs    │  GitHub      │
│  (Run Once) │ ───────>│  EKS + VPC + ALB │<────────│  Actions +   │
└─────────────┘         └──────────────────┘ deploys │  Helm        │
                                ↑                     └──────────────┘
                                │                            │
                                │                            ↓
                                └────────────────────  Kubernetes Pods
                                                      (product-service,
                                                       order-service)
```

### What Does What?

| Tool | Creates | When | How Often |
|------|---------|------|-----------|
| **Terraform** | AWS infrastructure (VPC, EKS cluster, Load Balancer) | Manual script | Once (or when infrastructure changes) |
| **GitHub Actions** | Docker images from Java code | Automatic on git push | Every code change |
| **Helm** | Kubernetes deployments (Pods, Services, Ingress) | Via GitHub Actions | Every code change |

## Step 1: Deploy Infrastructure (10-12 minutes)

This creates the foundation - VPC, EKS cluster, worker nodes, and Load Balancer Controller.

```bash
# Navigate to project root
cd kubernetes-code

# Make scripts executable
chmod +x scripts/*.sh

# Deploy infrastructure
./scripts/infra-up.sh
```

**What happens**:
1. Terraform initializes AWS provider
2. Creates VPC with 4 subnets (2 public, 2 private)
3. Creates NAT Gateway for private subnet internet access
4. Creates EKS cluster (ms-eks)
5. Launches 2 worker nodes (t3.small)
6. Installs AWS Load Balancer Controller via Helm
7. Configures kubectl to connect to cluster

**Cost**: ~$0.20/hour (~$4.80/day)

**Verify**:
```bash
# Quick verification
./scripts/verify-infra.sh

# Or check manually
# Check cluster
kubectl get nodes
# Should show 2 nodes in Ready state

# Check Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
# Should show 2 pods running
```

## Step 2: Deploy Applications (10-15 minutes)

Applications deploy automatically via GitHub Actions when you push code.

### Trigger Deployment

```bash
# Make any change or use empty commit
git commit --allow-empty -m "Deploy applications"
git push origin main
```

### What GitHub Actions Does

1. **Build Phase** (parallel):
   - Builds `product-service` with Maven
   - Builds `order-service` with Maven
   - Creates Docker images
   - Pushes images to Amazon ECR

2. **Deploy Phase** (via Helm):
   ```bash
   # GitHub Actions runs for each service:
   helm upgrade --install <service> ./helm-chart/springboot \
     --set image.repository=<ecr-image> \
     --set image.tag=<commit-sha> \
     --set service.name=<name> \
     --set service.port=80
   ```

3. **What Helm Creates**:
   - **Deployment**: 2 replicas of each service
   - **Service**: Internal DNS (hello.default.svc.cluster.local)
   - **Ingress**: ALB routing rules
   - **HPA**: Auto-scaling (2-10 pods based on CPU)

### Monitor Deployment

**Option 1 - GitHub UI**:
```
https://github.com/YOUR_USERNAME/EKS-project/actions
```

**Option 2 - Command Line**:
```bash
# Watch pods starting
kubectl get pods -n default --watch

# Expected output:
NAME                                READY   STATUS    AGE
hello-springboot-xxx-yyy            1/1     Running   2m
client-springboot-xxx-zzz           1/1     Running   2m
```

**Option 3 - Helm**:
```bash
# Check Helm releases
helm list -n default

# Should show:
NAME    NAMESPACE   REVISION   STATUS     CHART
hello   default     1          deployed   springboot-0.1.1
client  default     1          deployed   springboot-0.1.1
```

## Step 3: Get Access URL (1-2 minutes)

After pods are running, ALB needs ~2 minutes to become healthy.

```bash
# Get ALB DNS
kubectl get ingress -n default

# Or one-liner
kubectl get ingress -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

**Example output**: `k8s-microservices-ff36519e67-1234567890.us-east-1.elb.amazonaws.com`

## Step 4: Test Services

### Web UI
Open in browser:
```
http://<ALB-DNS>/
```

You'll see an interactive UI with two service cards.

### API Endpoints

**1. Messaging (Bi-directional)**:

```bash
# order-service → product-service
curl -X POST http://<ALB-DNS>/send-to-hello \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Order Service!"}'

# product-service → order-service
curl -X POST http://<ALB-DNS>/hello/send-to-client \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Product Service!"}'
```

**2. Item Management (CRUD)**:

```bash
# Create item via product-service
curl -X POST http://<ALB-DNS>/hello/create-item \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"High performance laptop","price":999.99}'

# Get all items from order-service
curl http://<ALB-DNS>/api/items

# Get specific item
curl http://<ALB-DNS>/api/items/1
```

## Understanding the Deployment

### How Helm Works

**Helm Chart** = Template for Kubernetes resources

Located at: `helm-chart/springboot/`

```
helm-chart/springboot/
├── Chart.yaml          # Chart info (name: springboot, version: 0.1.1)
├── values.yaml         # Default configuration
└── templates/
    ├── deployment.yaml # Pod template (replicas, image, ports)
    ├── service.yaml    # Internal DNS (ClusterIP)
    ├── ingress.yaml    # ALB routing rules
    ├── hpa.yaml        # Auto-scaling (min: 2, max: 10)
    └── serviceaccount.yaml
```

**Helm Values** (what GitHub Actions sets):
```yaml
image:
  repository: 123456.dkr.ecr.us-east-1.amazonaws.com/hello-service
  tag: abc123def456  # Git commit SHA

service:
  name: hello
  port: 80

env:
  CLIENT_SERVICE_URL: http://client.default.svc.cluster.local

ingress:
  enabled: true
  className: alb
  hosts:
    - paths:
        - path: /hello
          pathType: Prefix
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: microservices
    alb.ingress.kubernetes.io/group.order: "1"
```

### Routing Flow

```
User Request
    ↓
AWS ALB (Internet-facing)
    ↓
ALB Rule Priority 1: /hello/* → product-service (hello.default.svc.cluster.local)
ALB Rule Priority 2: /*       → order-service (client.default.svc.cluster.local)
    ↓
Kubernetes Service (ClusterIP)
    ↓
Pod (Container running Spring Boot app)
```

### Service Discovery

Services communicate via Kubernetes DNS:

```java
// In product-service
@Value("${CLIENT_SERVICE_URL}")
private String clientServiceUrl; // = http://client.default.svc.cluster.local

restTemplate.postForObject(clientServiceUrl + "/api/items", item, Map.class);
```

**DNS Format**: `<service-name>.<namespace>.svc.cluster.local`

## Cleanup

Destroy all resources to avoid charges:

```bash
./scripts/infra-down.sh
```

Confirm with `yes` when prompted.

**What gets deleted**:
- ✅ EKS cluster and worker nodes
- ✅ Load Balancers
- ✅ VPC, subnets, NAT Gateway
- ✅ Security groups
- ❌ ECR repositories (manual deletion needed)

**Delete ECR repositories** (optional):
```bash
aws ecr delete-repository --repository-name hello-service --region us-east-1 --force
aws ecr delete-repository --repository-name client-service --region us-east-1 --force
```

## Troubleshooting

### Use Verification Script

```bash
# Comprehensive infrastructure check
./scripts/verify-infra.sh

# Or with custom cluster name
./scripts/verify-infra.sh my-cluster-name us-east-1
```

**What it checks**:
- ✅ AWS CLI configuration
- ✅ VPC, subnets, NAT Gateway, Internet Gateway
- ✅ EKS cluster status and version
- ✅ Node group status and count
- ✅ Kubernetes nodes (via kubectl)
- ✅ System pods and ALB controller
- ✅ Application deployments
- ✅ Ingress and Load Balancer
- ✅ ECR repositories

### Pods not starting

```bash
# Check pod status
kubectl get pods -n default

# Check pod details
kubectl describe pod <pod-name> -n default

# View logs
kubectl logs <pod-name> -n default --tail=50

# Common issues:
# - Image pull error: Check ECR repository exists and has images
# - CrashLoopBackOff: Check application logs
# - Pending: Check node resources (kubectl describe nodes)
```

### ALB not created

```bash
# Check ingress status
kubectl get ingress -n default
kubectl describe ingress hello-springboot -n default

# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Common issues:
# - Controller not running: Check if pods are healthy
# - IAM permissions: Check IRSA role has correct permissions
# - Subnet tags: Ensure subnets have required tags
```

### Service communication failing

```bash
# Test DNS resolution from pod
kubectl exec -it <product-pod-name> -n default -- nslookup client.default.svc.cluster.local

# Check security groups
# Node security group needs self-referencing rule:
# Type: All TCP, Source: <same security group>

# Verify services
kubectl get svc -n default
```

### GitHub Actions failing

1. Check Actions tab: `https://github.com/YOUR_USERNAME/EKS-project/actions`
2. Verify AWS credentials in GitHub Secrets
3. Ensure EKS cluster exists and is accessible
4. Check if ECR repositories exist

## Next Steps

1. **Customize Services**: Edit Java code in `microservices/`
2. **Modify Helm Chart**: Update templates in `helm-chart/springboot/`
3. **Scale Services**: `kubectl scale deployment hello-springboot --replicas=5 -n default`
4. **View Metrics**: Install Prometheus/Grafana for monitoring
5. **Add SSL**: Configure ACM certificate and update ingress annotations

## Learn More

- **Terraform**: See [terraform/INFRASTRUCTURE.md](terraform/INFRASTRUCTURE.md)
- **Architecture**: See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- **Helm Charts**: https://helm.sh/docs/
- **EKS**: https://docs.aws.amazon.com/eks/

## Cost Estimate

**Running 24 hours** (no free tier):
- EKS cluster: $2.40 (control plane)
- EC2 t3.small × 2: $0.0208/hr × 2 × 24 = $1.00
- NAT Gateway: $0.045/hr × 24 = $1.08
- ALB: $0.0225/hr × 24 = $0.54
- Data transfer: ~$0.20

**Total**: ~$5.22/day (~$157/month)

**With free tier** (first 12 months):
- t3.small: 750 hours free/month
- Saves: ~$30/month

**Tip**: Destroy when not in use!
