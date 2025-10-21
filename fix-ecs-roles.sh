#!/bin/bash

# Fix ECS Roles for DevOpsCanvas FinOps
set -e

echo "🔧 Fixing ECS Roles for DevOpsCanvas FinOps"
echo "==========================================="

AWS_REGION="${AWS_REGION:-us-east-1}"

# Check if ecsTaskRole exists, if not create it
if ! aws iam get-role --role-name ecsTaskRole &>/dev/null; then
    echo "📋 Creating ecsTaskRole..."
    
    # Create trust policy
    cat > /tmp/ecs-task-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create the role
    aws iam create-role \
        --role-name ecsTaskRole \
        --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json \
        --description "ECS Task Role for DevOpsCanvas services"
    
    # Create basic policy for ECS tasks
    cat > /tmp/ecs-task-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

    # Create and attach the policy
    aws iam put-role-policy \
        --role-name ecsTaskRole \
        --policy-name ECSTaskBasicPolicy \
        --policy-document file:///tmp/ecs-task-policy.json
    
    rm -f /tmp/ecs-task-policy.json
    
    echo "✅ ecsTaskRole created"
    
    # Clean up
    rm -f /tmp/ecs-task-trust-policy.json
else
    echo "✅ ecsTaskRole already exists"
fi

# Update the task definition to remove taskRoleArn or use correct role
echo "📋 Updating task definition..."

# Get current task definition
TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition devopscanvas-finops-task \
    --region $AWS_REGION \
    --query 'taskDefinition')

# Remove problematic fields and update
NEW_TASK_DEF=$(echo "$TASK_DEF" | jq '
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

# Save to file
echo "$NEW_TASK_DEF" > /tmp/updated-task-definition.json

# Register new task definition
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file:///tmp/updated-task-definition.json \
    --region $AWS_REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "✅ New task definition registered: $NEW_TASK_DEF_ARN"

# Update the service to use new task definition
echo "🚀 Updating ECS service..."
aws ecs update-service \
    --cluster devopscanvas-cluster \
    --service devopscanvas-finops-service \
    --task-definition "$NEW_TASK_DEF_ARN" \
    --force-new-deployment \
    --region $AWS_REGION

echo "✅ Service updated with new task definition"

# Clean up
rm -f /tmp/updated-task-definition.json

echo ""
echo "🎉 ECS roles fixed successfully!"
echo ""
echo "📊 Monitor deployment:"
echo "aws ecs describe-services --cluster devopscanvas-cluster --services devopscanvas-finops-service --region $AWS_REGION"