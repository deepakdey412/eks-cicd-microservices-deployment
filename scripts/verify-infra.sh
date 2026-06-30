#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="${1:-ms-eks}"
AWS_REGION="${2:-us-east-1}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Infrastructure Verification Script                    ║${NC}"
echo -e "${BLUE}║     Cluster: ${CLUSTER_NAME}                                     ║${NC}"
echo -e "${BLUE}║     Region: ${AWS_REGION}                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" == "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" == "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
        ((WARNINGS++))
    else
        echo -e "${RED}✗${NC} $message"
        ((ERRORS++))
    fi
}

echo -e "${YELLOW}[1/7] Checking AWS CLI Configuration...${NC}"
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_status "OK" "AWS CLI configured (Account: $ACCOUNT_ID)"
else
    print_status "FAIL" "AWS CLI not configured or invalid credentials"
fi
echo ""

echo -e "${YELLOW}[2/7] Checking VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=*${CLUSTER_NAME}*" \
    --region ${AWS_REGION} \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    print_status "OK" "VPC exists: $VPC_ID"
    
    # Check Subnets
    SUBNET_COUNT=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --region ${AWS_REGION} \
        --query 'length(Subnets)' \
        --output text 2>/dev/null)
    
    if [ "$SUBNET_COUNT" -ge 4 ]; then
        print_status "OK" "Subnets configured: $SUBNET_COUNT subnets found"
    else
        print_status "WARN" "Expected 4+ subnets, found: $SUBNET_COUNT"
    fi
    
    # Check NAT Gateway
    NAT_COUNT=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available" \
        --region ${AWS_REGION} \
        --query 'length(NatGateways)' \
        --output text 2>/dev/null)
    
    if [ "$NAT_COUNT" -ge 1 ]; then
        print_status "OK" "NAT Gateway exists: $NAT_COUNT gateway(s)"
    else
        print_status "FAIL" "NAT Gateway not found or not available"
    fi
    
    # Check Internet Gateway
    IGW_COUNT=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --region ${AWS_REGION} \
        --query 'length(InternetGateways)' \
        --output text 2>/dev/null)
    
    if [ "$IGW_COUNT" -ge 1 ]; then
        print_status "OK" "Internet Gateway attached"
    else
        print_status "FAIL" "Internet Gateway not found"
    fi
else
    print_status "FAIL" "VPC not found"
fi
echo ""

echo -e "${YELLOW}[3/7] Checking EKS Cluster...${NC}"
CLUSTER_STATUS=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query 'cluster.status' \
    --output text 2>/dev/null)

if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    print_status "OK" "EKS Cluster is ACTIVE"
    
    # Get cluster endpoint
    CLUSTER_ENDPOINT=$(aws eks describe-cluster \
        --name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --query 'cluster.endpoint' \
        --output text 2>/dev/null)
    print_status "OK" "Cluster endpoint: $CLUSTER_ENDPOINT"
    
    # Check Kubernetes version
    K8S_VERSION=$(aws eks describe-cluster \
        --name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --query 'cluster.version' \
        --output text 2>/dev/null)
    print_status "OK" "Kubernetes version: $K8S_VERSION"
    
elif [ -n "$CLUSTER_STATUS" ]; then
    print_status "WARN" "EKS Cluster status: $CLUSTER_STATUS (not ACTIVE)"
else
    print_status "FAIL" "EKS Cluster not found: $CLUSTER_NAME"
fi
echo ""

echo -e "${YELLOW}[4/7] Checking Node Group...${NC}"
# Try multiple node group name patterns
NODEGROUP_STATUS=""
NODEGROUP_NAME=""

# Try common patterns
for pattern in "${CLUSTER_NAME}-node-group" "${CLUSTER_NAME}-node" "node-group" "nodes"; do
    STATUS=$(aws eks list-nodegroups \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --query "nodegroups[?contains(@, '${pattern}')] | [0]" \
        --output text 2>/dev/null)
    
    if [ -n "$STATUS" ] && [ "$STATUS" != "None" ]; then
        NODEGROUP_NAME=$STATUS
        break
    fi
done

# If still not found, get the first node group
if [ -z "$NODEGROUP_NAME" ]; then
    NODEGROUP_NAME=$(aws eks list-nodegroups \
        --cluster-name ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --query 'nodegroups[0]' \
        --output text 2>/dev/null)
fi

if [ -n "$NODEGROUP_NAME" ] && [ "$NODEGROUP_NAME" != "None" ]; then
    NODEGROUP_STATUS=$(aws eks describe-nodegroup \
        --cluster-name ${CLUSTER_NAME} \
        --nodegroup-name "${NODEGROUP_NAME}" \
        --region ${AWS_REGION} \
        --query 'nodegroup.status' \
        --output text 2>/dev/null)
    
    if [ "$NODEGROUP_STATUS" == "ACTIVE" ]; then
        print_status "OK" "Node Group is ACTIVE (${NODEGROUP_NAME})"
        
        # Get node count
        DESIRED_SIZE=$(aws eks describe-nodegroup \
            --cluster-name ${CLUSTER_NAME} \
            --nodegroup-name "${NODEGROUP_NAME}" \
            --region ${AWS_REGION} \
            --query 'nodegroup.scalingConfig.desiredSize' \
            --output text 2>/dev/null)
        
        INSTANCE_TYPE=$(aws eks describe-nodegroup \
            --cluster-name ${CLUSTER_NAME} \
            --nodegroup-name "${NODEGROUP_NAME}" \
            --region ${AWS_REGION} \
            --query 'nodegroup.instanceTypes[0]' \
            --output text 2>/dev/null)
        
        print_status "OK" "Desired nodes: $DESIRED_SIZE (Instance type: $INSTANCE_TYPE)"
        
    elif [ -n "$NODEGROUP_STATUS" ]; then
        print_status "WARN" "Node Group status: $NODEGROUP_STATUS (not ACTIVE)"
    fi
else
    # Check if we have running nodes anyway
    if command -v kubectl &> /dev/null && kubectl get nodes &>/dev/null; then
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        if [ "$NODE_COUNT" -gt 0 ]; then
            print_status "OK" "Node Group exists (detected via kubectl: $NODE_COUNT nodes running)"
        else
            print_status "FAIL" "Node Group not found"
        fi
    else
        print_status "WARN" "Node Group not found via AWS API (may have custom name)"
    fi
fi
echo ""

echo -e "${YELLOW}[5/7] Checking Kubernetes Resources (requires kubectl)...${NC}"
if command -v kubectl &> /dev/null; then
    # Try to get nodes
    if kubectl get nodes &>/dev/null; then
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
        
        if [ "$NODE_COUNT" -gt 0 ]; then
            print_status "OK" "Nodes: $READY_NODES/$NODE_COUNT Ready"
            
            # List nodes
            kubectl get nodes --no-headers 2>/dev/null | while read line; do
                NODE_NAME=$(echo $line | awk '{print $1}')
                NODE_STATUS=$(echo $line | awk '{print $2}')
                echo "    - $NODE_NAME: $NODE_STATUS"
            done
        else
            print_status "FAIL" "No nodes found in cluster"
        fi
        
        # Check system pods
        SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
        RUNNING_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running ")
        
        if [ "$SYSTEM_PODS" -gt 0 ]; then
            print_status "OK" "System pods: $RUNNING_SYSTEM_PODS/$SYSTEM_PODS Running"
        else
            print_status "WARN" "No system pods found"
        fi
        
        # Check ALB Controller
        ALB_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
        ALB_RUNNING=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep -c " Running ")
        
        if [ "$ALB_RUNNING" -gt 0 ]; then
            print_status "OK" "AWS Load Balancer Controller: $ALB_RUNNING/$ALB_PODS Running"
        else
            print_status "WARN" "AWS Load Balancer Controller not running"
        fi
        
    else
        print_status "WARN" "kubectl configured but cannot connect to cluster"
        echo "    Run: aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}"
    fi
else
    print_status "WARN" "kubectl not installed - skipping Kubernetes checks"
fi
echo ""

echo -e "${YELLOW}[6/7] Checking Application Deployments...${NC}"
if kubectl get pods -n default &>/dev/null; then
    # Check product-service
    PRODUCT_PODS=$(kubectl get pods -n default -l app.kubernetes.io/name=springboot,app.kubernetes.io/instance=hello --no-headers 2>/dev/null | wc -l)
    PRODUCT_RUNNING=$(kubectl get pods -n default -l app.kubernetes.io/name=springboot,app.kubernetes.io/instance=hello --no-headers 2>/dev/null | grep -c " Running ")
    
    if [ "$PRODUCT_PODS" -gt 0 ]; then
        if [ "$PRODUCT_RUNNING" -eq "$PRODUCT_PODS" ]; then
            print_status "OK" "product-service: $PRODUCT_RUNNING/$PRODUCT_PODS Running"
        else
            print_status "WARN" "product-service: $PRODUCT_RUNNING/$PRODUCT_PODS Running"
        fi
    else
        print_status "WARN" "product-service: Not deployed"
    fi
    
    # Check order-service
    ORDER_PODS=$(kubectl get pods -n default -l app.kubernetes.io/name=springboot,app.kubernetes.io/instance=client --no-headers 2>/dev/null | wc -l)
    ORDER_RUNNING=$(kubectl get pods -n default -l app.kubernetes.io/name=springboot,app.kubernetes.io/instance=client --no-headers 2>/dev/null | grep -c " Running ")
    
    if [ "$ORDER_PODS" -gt 0 ]; then
        if [ "$ORDER_RUNNING" -eq "$ORDER_PODS" ]; then
            print_status "OK" "order-service: $ORDER_RUNNING/$ORDER_PODS Running"
        else
            print_status "WARN" "order-service: $ORDER_RUNNING/$ORDER_PODS Running"
        fi
    else
        print_status "WARN" "order-service: Not deployed"
    fi
    
    # Check Services
    SVC_COUNT=$(kubectl get svc -n default --no-headers 2>/dev/null | grep -v kubernetes | wc -l)
    if [ "$SVC_COUNT" -gt 0 ]; then
        print_status "OK" "Kubernetes Services: $SVC_COUNT service(s) found"
    else
        print_status "WARN" "No application services found"
    fi
else
    print_status "WARN" "Cannot check applications - kubectl not connected"
fi
echo ""

echo -e "${YELLOW}[7/7] Checking Ingress and Load Balancer...${NC}"
if kubectl get ingress -n default &>/dev/null; then
    INGRESS_COUNT=$(kubectl get ingress -n default --no-headers 2>/dev/null | wc -l)
    
    if [ "$INGRESS_COUNT" -gt 0 ]; then
        print_status "OK" "Ingress resources: $INGRESS_COUNT found"
        
        # Get ALB hostname
        ALB_HOSTNAME=$(kubectl get ingress -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        
        if [ -n "$ALB_HOSTNAME" ] && [ "$ALB_HOSTNAME" != "null" ]; then
            print_status "OK" "Application Load Balancer: $ALB_HOSTNAME"
            
            # Test ALB connectivity
            echo -e "\n    ${BLUE}Testing ALB connectivity...${NC}"
            if curl -s --connect-timeout 5 "http://${ALB_HOSTNAME}/health" &>/dev/null; then
                print_status "OK" "ALB is reachable"
            else
                print_status "WARN" "ALB may not be fully ready yet (this can take 2-3 minutes)"
            fi
        else
            print_status "WARN" "ALB hostname not assigned yet"
        fi
        
        # List ingress details
        echo ""
        echo "    Ingress Details:"
        kubectl get ingress -n default 2>/dev/null | tail -n +2 | while read line; do
            echo "    - $line"
        done
    else
        print_status "WARN" "No ingress resources found"
    fi
    
    # Check ALB in AWS
    ALB_COUNT=$(aws elbv2 describe-load-balancers \
        --region ${AWS_REGION} \
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-microservices')] | length(@)" \
        --output text 2>/dev/null)
    
    if [ "$ALB_COUNT" -gt 0 ]; then
        print_status "OK" "AWS ALB count: $ALB_COUNT"
    else
        print_status "WARN" "No ALB found in AWS (may still be creating)"
    fi
else
    print_status "WARN" "Cannot check ingress - kubectl not connected"
fi
echo ""

# Check ECR repositories
echo -e "${YELLOW}[Bonus] Checking ECR Repositories...${NC}"
HELLO_ECR=$(aws ecr describe-repositories \
    --repository-names hello-service \
    --region ${AWS_REGION} \
    --query 'repositories[0].repositoryName' \
    --output text 2>/dev/null)

if [ "$HELLO_ECR" == "hello-service" ]; then
    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name hello-service \
        --region ${AWS_REGION} \
        --query 'length(imageIds)' \
        --output text 2>/dev/null)
    print_status "OK" "ECR hello-service: $IMAGE_COUNT image(s)"
else
    print_status "WARN" "ECR hello-service: Not created yet"
fi

CLIENT_ECR=$(aws ecr describe-repositories \
    --repository-names client-service \
    --region ${AWS_REGION} \
    --query 'repositories[0].repositoryName' \
    --output text 2>/dev/null)

if [ "$CLIENT_ECR" == "client-service" ]; then
    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name client-service \
        --region ${AWS_REGION} \
        --query 'length(imageIds)' \
        --output text 2>/dev/null)
    print_status "OK" "ECR client-service: $IMAGE_COUNT image(s)"
else
    print_status "WARN" "ECR client-service: Not created yet"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    VERIFICATION SUMMARY                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Infrastructure is ready.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Infrastructure mostly ready with $WARNINGS warning(s)${NC}"
    echo -e "${YELLOW}  Some components may still be initializing.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo -e "${RED}  Infrastructure is not complete or has issues.${NC}"
    exit 1
fi
