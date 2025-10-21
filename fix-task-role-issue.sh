#!/bin/bash

# Fix DevOpsCanvas FinOps Task Role Issue
set -e

echo "🔧 Fixing DevOpsCanvas FinOps Task Role Issue"
echo "============================================="

AWS_REGION="${AWS_REGION:-us-east-1}"
ECS_CLUSTER="devopscanvas-cluster"
ECS_SERVICE="devopscanvas-finops-service"
TASK_DEFINITION="devopscanvas-finops-task"

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
echo "  Task Definition: $TASK_DEFINITION"
echo ""

# Check if service exists
echo -e "${BLUE}🔍 Checking ECS service status...${NC}"
if aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region $AWS_REGION \
  --query 'services[0].serviceName' \
  --output text 2>/dev/null | grep -q "$ECS_SERVICE"; then
  echo -e "${GREEN}✅ ECS service exists${NC}"
else
  echo -e "${RED}❌ ECS service does not exist${NC}"
  echo "Please run the CI/CD pipeline to create the service first."
  exit 1
fi

# Get current task definition
echo -e "${BLUE}📋 Getting current task definition...${NC}"
CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
  --task-definition $TASK_DEFINITION \
  --region $AWS_REGION \
  --query 'taskDefinition')

if [ -z "$CURRENT_TASK_DEF" ] || [ "$CURRENT_TASK_DEF" = "null" ]; then
  echo -e "${RED}❌ Failed to fetch current task definition${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Current task definition fetched${NC}"

# Check if task definition has taskRoleArn
TASK_ROLE_ARN=$(echo "$CURRENT_TASK_DEF" | jq -r '.taskRoleArn // "null"')
echo "Current taskRoleArn: $TASK_ROLE_ARN"

if [ "$TASK_ROLE_ARN" = "null" ]; then
  echo -e "${GREEN}✅ Task definition already has no task role${NC}"
  echo "The issue might be with a previous deployment. Let's force a new deployment."
else
  echo -e "${YELLOW}⚠️ Task definition has taskRoleArn: $TASK_ROLE_ARN${NC}"
  echo "Creating new task definition without task role..."
  
  # Create new task definition without taskRoleArn
  NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | jq '
    del(.taskDefinitionArn) | 
    del(.revision) | 
    del(.status) | 
    del(.requiresAttributes) | 
    del(.placementConstraints) | 
    del(.compatibilities) | 
    del(.registeredAt) | 
    del(.registeredBy) |
    del(.taskRoleArn)
  ')
  
  # Save to temporary file
  echo "$NEW_TASK_DEF" > /tmp/fixed-task-definition.json
  
  # Register new task definition
  echo -e "${BLUE}🚀 Registering new task definition without task role...${NC}"
  NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file:///tmp/fixed-task-definition.json \
    --region $AWS_REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)
  
  if [ -z "$NEW_TASK_DEF_ARN" ] || [ "$NEW_TASK_DEF_ARN" = "None" ]; then
    echo -e "${RED}❌ Failed to register new task definition${NC}"
    echo "Task definition content:"
    cat /tmp/fixed-task-definition.json
    exit 1
  fi
  
  echo -e "${GREEN}✅ New task definition registered: $NEW_TASK_DEF_ARN${NC}"
  
  # Clean up
  rm -f /tmp/fixed-task-definition.json
fi

# Update service with force new deployment
echo -e "${BLUE}🚀 Updating ECS service with force new deployment...${NC}"
aws ecs update-service \
  --cluster $ECS_CLUSTER \
  --service $ECS_SERVICE \
  --force-new-deployment \
  --region $AWS_REGION > /dev/null

echo -e "${GREEN}✅ Service update initiated${NC}"

# Wait for deployment to stabilize
echo -e "${BLUE}⏳ Waiting for deployment to complete...${NC}"
echo "This may take a few minutes..."

# Monitor deployment for up to 10 minutes
MAX_WAIT=600
WAIT_INTERVAL=30
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  SERVICE_STATUS=$(aws ecs describe-services \
    --cluster $ECS_CLUSTER \
    --services $ECS_SERVICE \
    --region $AWS_REGION \
    --query 'services[0]')
  
  RUNNING_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.runningCount')
  DESIRED_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.desiredCount')
  DEPLOYMENT_STATUS=$(echo "$SERVICE_STATUS" | jq -r '.deployments[0].status')
  ROLLOUT_STATE=$(echo "$SERVICE_STATUS" | jq -r '.deployments[0].rolloutState // "IN_PROGRESS"')
  
  echo "📊 Status: $RUNNING_COUNT/$DESIRED_COUNT tasks, Deployment: $DEPLOYMENT_STATUS, Rollout: $ROLLOUT_STATE"
  
  # Check if deployment is complete
  if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$DEPLOYMENT_STATUS" = "PRIMARY" ] && [ "$ROLLOUT_STATE" = "COMPLETED" ]; then
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    break
  fi
  
  # Check for failed deployment
  if [ "$DEPLOYMENT_STATUS" = "FAILED" ] || [ "$ROLLOUT_STATE" = "FAILED" ]; then
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo "Service details:"
    echo "$SERVICE_STATUS" | jq '.deployments[0]'
    exit 1
  fi
  
  sleep $WAIT_INTERVAL
  ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

# Final status check
echo ""
echo -e "${BLUE}📊 Final Status Check:${NC}"
FINAL_STATUS=$(aws ecs describe-services \
  --cluster $ECS_CLUSTER \
  --services $ECS_SERVICE \
  --region $AWS_REGION \
  --query 'services[0].{runningCount:runningCount,desiredCount:desiredCount,status:status}')

RUNNING_COUNT=$(echo "$FINAL_STATUS" | jq -r '.runningCount')
DESIRED_COUNT=$(echo "$FINAL_STATUS" | jq -r '.desiredCount')
SERVICE_STATUS=$(echo "$FINAL_STATUS" | jq -r '.status')

echo "Service Status: $SERVICE_STATUS"
echo "Running Tasks: $RUNNING_COUNT/$DESIRED_COUNT"

if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$RUNNING_COUNT" != "0" ]; then
  echo -e "${GREEN}🎉 DevOpsCanvas FinOps service is running successfully!${NC}"
  
  # Test health endpoint if possible
  echo ""
  echo -e "${BLUE}🏥 Testing service health...${NC}"
  
  # Get task details for health check
  TASK_ARN=$(aws ecs list-tasks \
    --cluster $ECS_CLUSTER \
    --service-name $ECS_SERVICE \
    --region $AWS_REGION \
    --query 'taskArns[0]' \
    --output text)
  
  if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    TASK_DETAILS=$(aws ecs describe-tasks \
      --cluster $ECS_CLUSTER \
      --tasks "$TASK_ARN" \
      --region $AWS_REGION \
      --query 'tasks[0].{lastStatus:lastStatus,healthStatus:healthStatus}')
    
    TASK_STATUS=$(echo "$TASK_DETAILS" | jq -r '.lastStatus')
    HEALTH_STATUS=$(echo "$TASK_DETAILS" | jq -r '.healthStatus')
    
    echo "Task Status: $TASK_STATUS"
    echo "Health Status: $HEALTH_STATUS"
    
    if [ "$HEALTH_STATUS" = "HEALTHY" ]; then
      echo -e "${GREEN}✅ Service is healthy and ready!${NC}"
    else
      echo -e "${YELLOW}⚠️ Service is starting up, health check pending${NC}"
    fi
  fi
  
else
  echo -e "${YELLOW}⚠️ Service may not be fully healthy yet${NC}"
  echo "Check the ECS console for more details."
fi

echo ""
echo -e "${GREEN}🎉 Task role issue fix completed!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "- Removed taskRoleArn from task definition"
echo "- Updated ECS service with new configuration"
echo "- Service is now consistent with portal service setup"
echo ""
echo -e "${BLUE}🔗 Useful commands:${NC}"
echo "# Monitor service"
echo "aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION"
echo ""
echo "# View logs"
echo "aws logs tail /ecs/devopscanvas-finops --follow --region $AWS_REGION"