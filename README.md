# EKS-CICD-Microservices-Deployment

Production-ready microservices demonstrating service communication, automated CI/CD, and infrastructure as code on AWS.

## Quick Overview

Two Spring Boot services on Amazon EKS:

- **product-service**: Creates and manages products
- **order-service**: Stores orders and serves web UI

Both communicate internally via Kubernetes DNS and are exposed via AWS Application Load Balancer.

## Quick Links

- 📘 [Setup Guide (QUICKSTART.md)](QUICKSTART.md)
- 📐 [Architecture & Flow (PROJECT_SUMMARY.md)](PROJECT_SUMMARY.md)
- 🏗️ [Infrastructure Details (terraform/INFRASTRUCTURE.md)](terraform/INFRASTRUCTURE.md)

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

## Technology Stack

**Backend**: Java 17, Spring Boot 3.2.5, Maven  
**Infrastructure**: AWS EKS, VPC, ALB, Terraform  
**CI/CD**: GitHub Actions, Helm Charts  
**Container**: Docker, Amazon ECR

## Architecture

<img src="output-screenshots/00-requestflow.png" alt="request-flow" border="4" width="480" style="border:4px solid #ffffff;" />

## Output Screenshots

Step-by-step outputs captured while deploying and verifying this project (see `output-screenshots/`):

| Step | Screenshot                                                                                                                                           | Description                                       |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| 1    | <img src="output-screenshots/01-infra-up.png" alt="01-infra-up" border="4" width="480" style="border:4px solid #888;" />                             | Running `infra-up.sh` to provision infrastructure |
| 2    | <img src="output-screenshots/02-verify-infra.png" alt="02-verify-infra" border="4" width="480" style="border:4px solid #888;" />                     | Verifying infrastructure with `verify-infra.sh`   |
| 3    | <img src="output-screenshots/03-verify-nodes-pods-albc.png" alt="03-verify-nodes-pods-albc" border="4" width="480" style="border:4px solid #888;" /> | Verifying nodes, pods, and ALB controller         |
| 4    | <img src="output-screenshots/04-git-pushed.png" alt="04-git-pushed" border="4" width="480" style="border:4px solid #888;" />                         | Pushing code to trigger CI/CD                     |
| 5    | <img src="output-screenshots/05-github-action.png" alt="05-github-action" border="4" width="480" style="border:4px solid #888;" />                   | GitHub Actions pipeline running                   |
| 6    | <img src="output-screenshots/07-eks-cluster.png" alt="07-eks-cluster" border="4" width="480" style="border:4px solid #888;" />                       | EKS cluster view                                  |
| 7    | <img src="output-screenshots/08-instance-node.png" alt="08-instance-node" border="4" width="480" style="border:4px solid #888;" />                   | EC2 instance / node details                       |
| 8    | <img src="output-screenshots/09-pods-in-eks.png" alt="09-pods-in-eks" border="4" width="480" style="border:4px solid #888;" />                       | Pods running inside EKS                           |
| 9    | <img src="output-screenshots/10-wroking-project.png" alt="10-wroking-project" border="4" width="480" style="border:4px solid #888;" />               | Final working project in the browser              |

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

## Contact

For any queries, feel free to DM me on LinkedIn: [linkedin.com/in/deepakdey](https://linkedin.com/in/deepakdey)

---
