#!/bin/bash

# DevOpsCanvas FinOps GitHub Secrets Setup
set -e

echo "🔐 Setting up GitHub Secrets for DevOpsCanvas FinOps"
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) not found. Please install it first.${NC}"
    echo "Install with: brew install gh"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub CLI.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured.${NC}"
    echo "Please run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo -e "${GREEN}✅ AWS credentials configured${NC}"
echo "  Account ID: $AWS_ACCOUNT_ID"
echo "  Region: $AWS_REGION"

# Get current AWS credentials
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo -e "${RED}❌ AWS access keys not found in configuration.${NC}"
    echo "Please ensure AWS CLI is configured with access keys."
    exit 1
fi

echo ""
echo -e "${BLUE}🔑 Setting up GitHub repository secrets...${NC}"

# Set AWS credentials
echo "Setting AWS_ACCESS_KEY_ID..."
if gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"; then
    echo -e "${GREEN}✅ AWS_ACCESS_KEY_ID set${NC}"
else
    echo -e "${RED}❌ Failed to set AWS_ACCESS_KEY_ID${NC}"
    exit 1
fi

echo "Setting AWS_SECRET_ACCESS_KEY..."
if gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"; then
    echo -e "${GREEN}✅ AWS_SECRET_ACCESS_KEY set${NC}"
else
    echo -e "${RED}❌ Failed to set AWS_SECRET_ACCESS_KEY${NC}"
    exit 1
fi

# Optional: Set Docker Hub credentials
echo ""
echo -e "${BLUE}🐳 Docker Hub credentials (optional)${NC}"
echo "Docker Hub credentials are optional but recommended to avoid rate limits."
read -p "Do you want to set Docker Hub credentials? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Docker Hub Username: " DOCKER_USERNAME
    read -s -p "Docker Hub Token/Password: " DOCKER_TOKEN
    echo
    
    if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_TOKEN" ]; then
        echo "Setting DOCKER_HUB_USERNAME..."
        if gh secret set DOCKER_HUB_USERNAME --body "$DOCKER_USERNAME"; then
            echo -e "${GREEN}✅ DOCKER_HUB_USERNAME set${NC}"
        else
            echo -e "${RED}❌ Failed to set DOCKER_HUB_USERNAME${NC}"
        fi
        
        echo "Setting DOCKER_HUB_TOKEN..."
        if gh secret set DOCKER_HUB_TOKEN --body "$DOCKER_TOKEN"; then
            echo -e "${GREEN}✅ DOCKER_HUB_TOKEN set${NC}"
        else
            echo -e "${RED}❌ Failed to set DOCKER_HUB_TOKEN${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Docker Hub credentials not provided${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Skipping Docker Hub credentials${NC}"
fi

echo ""
echo -e "${GREEN}🎉 GitHub secrets setup complete!${NC}"
echo ""
echo -e "${BLUE}📋 Configured secrets:${NC}"
gh secret list

echo ""
echo -e "${BLUE}🚀 Next steps:${NC}"
echo "1. Trigger a new workflow run:"
echo "   gh workflow run devopscanvas-finops-ci-cd.yml --field deployment_target=aws-ecs"
echo ""
echo "2. Monitor the workflow:"
echo "   gh run list --workflow=\"DevOpsCanvas FinOps - Complete CI/CD Pipeline\""
echo ""
echo "3. View workflow logs:"
echo "   gh run view --log"
echo ""
echo "4. Check ECS deployment:"
echo "   aws ecs describe-services --cluster devopscanvas-cluster --services devopscanvas-finops-service --region $AWS_REGION"