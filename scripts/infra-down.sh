#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== Infrastructure Destruction ===${NC}"
echo -e "${YELLOW}This will destroy all AWS resources!${NC}"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Destruction cancelled${NC}"
    exit 0
fi

cd terraform

echo -e "${YELLOW}Destroying infrastructure....${NC}"
terraform destroy -auto-approve

echo -e "\n${GREEN}=== Infrastructure Destroyed! ===${NC}"
