#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Infrastructure Deployment ===${NC}"

cd terraform

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}Planning infrastructure...${NC}"
terraform plan

echo -e "${YELLOW}Applying infrastructure...${NC}"
terraform apply -auto-approve

echo -e "\n${GREEN}=== Infrastructure Created Successfully! ===${NC}"

# Configure kubectl
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "ms-eks")
AWS_REGION=$(terraform output -raw region 2>/dev/null || echo "us-east-1")

echo -e "${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}

echo -e "\n${GREEN}Cluster ready!${NC}"
kubectl get nodes
