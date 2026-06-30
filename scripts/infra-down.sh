#!/usr/bin/env bash
# AWS EKS Infrastructure Cleanup Script
# Compatible with bash, Git Bash on Windows, and WSL

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-ms-eks}"
VPC_NAME="ms-eks-vpc"

echo -e "${RED}===================================${NC}"
echo -e "${RED}AWS INFRASTRUCTURE CLEANUP${NC}"
echo -e "${RED}===================================${NC}"
echo -e "${YELLOW}This will permanently delete:${NC}"
echo -e "${YELLOW}  - EKS Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${YELLOW}  - VPC: ${VPC_NAME}${NC}"
echo -e "${YELLOW}  - Load Balancers, NAT Gateways, etc.${NC}"
echo -e "${CYAN}Region: ${REGION}${NC}"
echo -e "${RED}===================================${NC}"
echo ""

read -p "Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled.${NC}"
    exit 0
fi

echo -e "\n${CYAN}[1/7] Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}ERROR: AWS CLI not configured${NC}"
    echo -e "${GRAY}Run: aws configure${NC}"
    exit 1
fi
CALLER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
echo -e "${GREEN}✓ Connected as: ${CALLER_ARN}${NC}"

echo -e "\n${CYAN}[2/7] Cleaning Kubernetes resources...${NC}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION} 2>/dev/null || true
kubectl delete ingress --all -n default --timeout=60s 2>/dev/null || true
kubectl delete svc --all -n default --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Done${NC}"
sleep 10

echo -e "\n${CYAN}[3/7] Deleting Load Balancers...${NC}"
LBS=$(aws elbv2 describe-load-balancers --region ${REGION} --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$LBS" ]; then
    for lb in $LBS; do
        echo -e "${GRAY}  Deleting: $(basename $lb)${NC}"
        aws elbv2 delete-load-balancer --load-balancer-arn $lb --region ${REGION} 2>/dev/null || true
    done
    echo -e "${GRAY}  Waiting 30s...${NC}"
    sleep 30
fi
echo -e "${GREEN}✓ Done${NC}"

echo -e "\n${CYAN}[4/7] Deleting EKS Cluster...${NC}"
if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} > /dev/null 2>&1; then
    echo -e "${GRAY}  Found cluster: ${CLUSTER_NAME}${NC}"
    
    # Delete node groups
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} --region ${REGION} --query "nodegroups" --output text 2>/dev/null || echo "")
    if [ -n "$NODE_GROUPS" ]; then
        for ng in $NODE_GROUPS; do
            echo -e "${GRAY}  Deleting node group: ${ng}${NC}"
            aws eks delete-nodegroup --cluster-name ${CLUSTER_NAME} --nodegroup-name $ng --region ${REGION} 2>/dev/null || true
        done
        echo -e "${GRAY}  Waiting 90s for node groups...${NC}"
        sleep 90
    fi
    
    # Delete cluster
    echo -e "${GRAY}  Deleting cluster...${NC}"
    aws eks delete-cluster --name ${CLUSTER_NAME} --region ${REGION} 2>/dev/null || true
    
    # Wait for deletion (max 15 min)
    echo -e "${GRAY}  Waiting for cluster deletion (5-10 min)...${NC}"
    MAX_WAIT=900
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if ! aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Cluster deleted${NC}"
            break
        fi
        echo -e "${GRAY}  Still deleting... (${WAITED}s)${NC}"
        sleep 30
        WAITED=$((WAITED + 30))
    done
else
    echo -e "${GREEN}✓ Cluster not found${NC}"
fi

echo -e "\n${CYAN}[5/7] Finding VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${VPC_NAME}" --region ${REGION} --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
    echo -e "${GREEN}✓ VPC not found${NC}"
    echo -e "\n${GREEN}===================================${NC}"
    echo -e "${GREEN}CLEANUP COMPLETE!${NC}"
    echo -e "${GREEN}===================================${NC}"
    exit 0
fi

echo -e "${GRAY}  VPC ID: ${VPC_ID}${NC}"

echo -e "\n${CYAN}[6/7] Deleting VPC dependencies...${NC}"

# NAT Gateways
echo -e "${GRAY}  Deleting NAT Gateways...${NC}"
NAT_GWS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available" --region ${REGION} --query "NatGateways[].NatGatewayId" --output text 2>/dev/null || echo "")
if [ -n "$NAT_GWS" ]; then
    for ngw in $NAT_GWS; do
        aws ec2 delete-nat-gateway --nat-gateway-id $ngw --region ${REGION} 2>/dev/null || true
    done
    sleep 60
fi

# Elastic IPs
echo -e "${GRAY}  Releasing Elastic IPs...${NC}"
EIPS=$(aws ec2 describe-addresses --region ${REGION} --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null || echo "")
if [ -n "$EIPS" ]; then
    for eip in $EIPS; do
        aws ec2 release-address --allocation-id $eip --region ${REGION} 2>/dev/null || true
    done
fi

# Route Tables
echo -e "${GRAY}  Deleting route tables...${NC}"
ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --region ${REGION} --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null || echo "")
if [ -n "$ROUTE_TABLES" ]; then
    for rtb in $ROUTE_TABLES; do
        aws ec2 delete-route-table --route-table-id $rtb --region ${REGION} 2>/dev/null || true
    done
fi

# Security Groups (multiple attempts for dependencies)
echo -e "${GRAY}  Deleting security groups...${NC}"
for attempt in {1..5}; do
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${VPC_ID}" --region ${REGION} --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
    
    if [ -z "$SGS" ]; then
        break
    fi
    
    for sg in $SGS; do
        # Revoke ingress rules
        INGRESS_RULES=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=${sg}" --region ${REGION} --query "SecurityGroupRules[?!IsEgress].SecurityGroupRuleId" --output text 2>/dev/null || echo "")
        for rule in $INGRESS_RULES; do
            aws ec2 revoke-security-group-ingress --group-id $sg --security-group-rule-ids $rule --region ${REGION} 2>/dev/null || true
        done
        
        # Revoke egress rules
        EGRESS_RULES=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=${sg}" --region ${REGION} --query "SecurityGroupRules[?IsEgress].SecurityGroupRuleId" --output text 2>/dev/null || echo "")
        for rule in $EGRESS_RULES; do
            aws ec2 revoke-security-group-egress --group-id $sg --security-group-rule-ids $rule --region ${REGION} 2>/dev/null || true
        done
        
        # Delete security group
        aws ec2 delete-security-group --group-id $sg --region ${REGION} 2>/dev/null || true
    done
    sleep 3
done

# Subnets
echo -e "${GRAY}  Deleting subnets...${NC}"
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region ${REGION} --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
if [ -n "$SUBNETS" ]; then
    for subnet in $SUBNETS; do
        aws ec2 delete-subnet --subnet-id $subnet --region ${REGION} 2>/dev/null || true
    done
fi

# Internet Gateways
echo -e "${GRAY}  Deleting Internet Gateways...${NC}"
IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --region ${REGION} --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
if [ -n "$IGWS" ]; then
    for igw in $IGWS; do
        aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id ${VPC_ID} --region ${REGION} 2>/dev/null || true
        aws ec2 delete-internet-gateway --internet-gateway-id $igw --region ${REGION} 2>/dev/null || true
    done
fi

# Network Interfaces
ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=${VPC_ID}" --region ${REGION} --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null || echo "")
if [ -n "$ENIS" ]; then
    for eni in $ENIS; do
        aws ec2 delete-network-interface --network-interface-id $eni --region ${REGION} 2>/dev/null || true
    done
    sleep 10
fi

echo -e "${GREEN}✓ Dependencies cleaned${NC}"

echo -e "\n${CYAN}[7/7] Deleting VPC...${NC}"
if aws ec2 delete-vpc --vpc-id ${VPC_ID} --region ${REGION} 2>/dev/null; then
    echo -e "${GREEN}✓ VPC deleted${NC}"
else
    echo -e "${YELLOW}⚠ VPC deletion failed (may have dependencies)${NC}"
fi

# Terraform cleanup
cd terraform 2>/dev/null && terraform destroy -auto-approve 2>/dev/null && cd .. || true

echo -e "\n${GREEN}===================================${NC}"
echo -e "${GREEN}✓ CLEANUP COMPLETE!${NC}"
echo -e "${GREEN}===================================${NC}"
echo -e "\n${CYAN}Deleted:${NC}"
echo -e "${GREEN}  ✓ EKS Cluster${NC}"
echo -e "${GREEN}  ✓ VPC & all dependencies${NC}"
echo -e "${GREEN}  ✓ Load Balancers${NC}"
echo -e "\n${YELLOW}Optional - Delete ECR repositories:${NC}"
echo -e "${GRAY}  aws ecr delete-repository --repository-name hello-service --region ${REGION} --force${NC}"
echo -e "${GRAY}  aws ecr delete-repository --repository-name client-service --region ${REGION} --force${NC}"
echo ""
