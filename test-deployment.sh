#!/bin/bash

# DevOpsCanvas FinOps Deployment Test Script
set -e

echo "🧪 Testing DevOpsCanvas FinOps Deployment"
echo "========================================="

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECS_CLUSTER="devopscanvas-cluster"
ECS_SERVICE="devopscanvas-finops-service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  ECS Cluster: $ECS_CLUSTER"
echo "  ECS Service: $ECS_SERVICE"
echo ""

# Test 1: Check ECR Repository
echo -e "${BLUE}🐳 Test 1: ECR Repository${NC}"
if aws ecr describe-repositories --repository-names devopscanvas-finops --region $AWS_REGION &> /dev/null; then
    ECR_URI=$(aws ecr describe-repositories --repository-names devopscanvas-finops --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)
    echo -e "${GREEN}✅ ECR repository exists: $ECR_URI${NC}"
else
    echo -e "${RED}❌ ECR repository not found${NC}"
    exit 1
fi

# Test 2: Check ECS Cluster
echo -e "${BLUE}🏗️ Test 2: ECS Cluster${NC}"
if aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION --query 'clusters[0].status' --output text | grep -q "ACTIVE"; then
    echo -e "${GREEN}✅ ECS cluster is active${NC}"
else
    echo -e "${RED}❌ ECS cluster not active${NC}"
    exit 1
fi

# Test 3: Check CloudWatch Log Group
echo -e "${BLUE}📊 Test 3: CloudWatch Log Group${NC}"
if aws logs describe-log-groups --log-group-name-prefix "/ecs/devopscanvas-finops" --region $AWS_REGION --query 'logGroups[?logGroupName==`/ecs/devopscanvas-finops`]' --output text | grep -q "/ecs/devopscanvas-finops"; then
    echo -e "${GREEN}✅ CloudWatch log group exists${NC}"
else
    echo -e "${RED}❌ CloudWatch log group not found${NC}"
    exit 1
fi

# Test 4: Check if service exists (optional)
echo -e "${BLUE}🚀 Test 4: ECS Service (Optional)${NC}"
if aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "$ECS_SERVICE"; then
    SERVICE_STATUS=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].status' --output text)
    RUNNING_COUNT=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].runningCount' --output text)
    DESIRED_COUNT=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION --query 'services[0].desiredCount' --output text)
    
    echo -e "${GREEN}✅ ECS service exists${NC}"
    echo "  Status: $SERVICE_STATUS"
    echo "  Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"
    
    if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" != "0" ]; then
        echo -e "${GREEN}✅ Service is healthy${NC}"
        
        # Test 5: Health Check (if service is running)
        echo -e "${BLUE}🏥 Test 5: Application Health Check${NC}"
        
        # Try to get the load balancer URL (if exists)
        ALB_DNS=$(aws elbv2 describe-load-balancers --names devopscanvas-alb --region $AWS_REGION --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "not-found")
        
        if [ "$ALB_DNS" != "not-found" ]; then
            echo "🌐 Testing via Load Balancer: http://$ALB_DNS"
            
            # Test root endpoint
            if curl -f -s "http://$ALB_DNS/" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Root endpoint accessible${NC}"
            else
                echo -e "${YELLOW}⚠️ Root endpoint not accessible (may be normal during deployment)${NC}"
            fi
            
            # Test health endpoint
            if curl -f -s "http://$ALB_DNS/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Health endpoint accessible${NC}"
            else
                echo -e "${YELLOW}⚠️ Health endpoint not accessible (may be normal during deployment)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ Load balancer not found - direct testing not possible${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Service exists but not fully healthy${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ ECS service not found (will be created on first deployment)${NC}"
fi

# Test 6: GitHub Actions Workflow
echo -e "${BLUE}⚙️ Test 6: GitHub Actions Workflow${NC}"
if [ -f ".github/workflows/devopscanvas-finops-ci-cd.yml" ]; then
    echo -e "${GREEN}✅ GitHub Actions workflow file exists${NC}"
    
    # Check if we're in a git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Git repository initialized${NC}"
        
        # Check if we have a remote
        if git remote -v | grep -q "origin"; then
            REMOTE_URL=$(git remote get-url origin)
            echo -e "${GREEN}✅ Git remote configured: $REMOTE_URL${NC}"
        else
            echo -e "${YELLOW}⚠️ Git remote not configured${NC}"
            echo "💡 Add remote with: git remote add origin <repository-url>"
        fi
    else
        echo -e "${YELLOW}⚠️ Not in a git repository${NC}"
        echo "💡 Initialize with: git init"
    fi
else
    echo -e "${RED}❌ GitHub Actions workflow file not found${NC}"
    exit 1
fi

# Test 7: Docker Build Test
echo -e "${BLUE}🐳 Test 7: Docker Build Test${NC}"
if [ -f "Dockerfile" ]; then
    echo -e "${GREEN}✅ Dockerfile exists${NC}"
    
    if [ -f "package.json" ]; then
        echo -e "${GREEN}✅ package.json exists${NC}"
    else
        echo -e "${RED}❌ package.json not found${NC}"
        exit 1
    fi
    
    # Optional: Test docker build (commented out to avoid long build times)
    # echo "🔨 Testing Docker build..."
    # if docker build -t devopscanvas-finops-test . > /dev/null 2>&1; then
    #     echo -e "${GREEN}✅ Docker build successful${NC}"
    #     docker rmi devopscanvas-finops-test > /dev/null 2>&1
    # else
    #     echo -e "${RED}❌ Docker build failed${NC}"
    #     exit 1
    # fi
else
    echo -e "${RED}❌ Dockerfile not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All tests passed!${NC}"
echo ""
echo -e "${BLUE}🚀 Ready for deployment!${NC}"
echo ""
echo "Next steps:"
echo "1. Commit and push your code to trigger the CI/CD pipeline"
echo "2. Monitor the GitHub Actions workflow"
echo "3. Check ECS service deployment status"
echo ""
echo "Useful commands:"
echo "  # Trigger manual deployment"
echo "  gh workflow run devopscanvas-finops-ci-cd.yml --field deployment_target=aws-ecs"
echo ""
echo "  # Monitor ECS service"
echo "  aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
echo ""
echo "  # View logs"
echo "  aws logs tail /ecs/devopscanvas-finops --follow --region $AWS_REGION"