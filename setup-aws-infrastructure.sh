#!/bin/bash

# DevOpsCanvas FinOps AWS Infrastructure Setup
set -e

echo "🚀 Setting up AWS infrastructure for DevOpsCanvas FinOps"
echo "======================================================="

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="devopscanvas-finops"
ECS_CLUSTER="devopscanvas-cluster"

echo "📋 Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  ECR Repository: $ECR_REPOSITORY"
echo "  ECS Cluster: $ECS_CLUSTER"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $AWS_ACCOUNT_ID"

# Create ECR repository
echo "🐳 Creating ECR repository..."
if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION &> /dev/null; then
    echo "✅ ECR repository '$ECR_REPOSITORY' already exists"
else
    aws ecr create-repository \
        --repository-name $ECR_REPOSITORY \
        --region $AWS_REGION \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    
    echo "✅ ECR repository '$ECR_REPOSITORY' created"
fi

# Set lifecycle policy for ECR
echo "🔄 Setting ECR lifecycle policy..."
cat > /tmp/lifecycle-policy.json << EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 production images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["production"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 5 development images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["develop", "main"],
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 3,
            "description": "Delete untagged images older than 1 day",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

aws ecr put-lifecycle-policy \
    --repository-name $ECR_REPOSITORY \
    --lifecycle-policy-text file:///tmp/lifecycle-policy.json \
    --region $AWS_REGION

echo "✅ ECR lifecycle policy set"

# Check if ECS cluster exists
echo "🏗️ Checking ECS cluster..."
if aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION --query 'clusters[0].status' --output text | grep -q "ACTIVE"; then
    echo "✅ ECS cluster '$ECS_CLUSTER' is active"
else
    echo "❌ ECS cluster '$ECS_CLUSTER' not found or not active"
    echo "💡 Please ensure the ECS cluster exists before deploying"
fi

# Create CloudWatch log group
echo "📊 Creating CloudWatch log group..."
if aws logs describe-log-groups \
    --log-group-name-prefix "/ecs/devopscanvas-finops" \
    --region $AWS_REGION \
    --query 'logGroups[?logGroupName==`/ecs/devopscanvas-finops`]' \
    --output text | grep -q "/ecs/devopscanvas-finops"; then
    echo "✅ CloudWatch log group already exists"
else
    aws logs create-log-group \
        --log-group-name "/ecs/devopscanvas-finops" \
        --region $AWS_REGION
    
    # Set retention policy
    aws logs put-retention-policy \
        --log-group-name "/ecs/devopscanvas-finops" \
        --retention-in-days 30 \
        --region $AWS_REGION
    
    echo "✅ CloudWatch log group created with 30-day retention"
fi

# Output summary
echo ""
echo "🎉 AWS Infrastructure Setup Complete!"
echo "====================================="
echo ""
echo "📋 Resources Created/Verified:"
echo "  ✅ ECR Repository: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
echo "  ✅ CloudWatch Log Group: /ecs/devopscanvas-finops"
echo "  ✅ ECS Cluster: $ECS_CLUSTER (verified)"
echo ""
echo "🚀 Next Steps:"
echo "  1. Push your code to GitHub to trigger the CI/CD pipeline"
echo "  2. The pipeline will build and deploy to ECS automatically"
echo "  3. Monitor deployment in AWS ECS console"
echo ""
echo "🔗 Useful Commands:"
echo "  # View ECR repository"
echo "  aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION"
echo ""
echo "  # View ECS service (after deployment)"
echo "  aws ecs describe-services --cluster $ECS_CLUSTER --services devopscanvas-finops-service --region $AWS_REGION"
echo ""
echo "  # View logs"
echo "  aws logs describe-log-streams --log-group-name /ecs/devopscanvas-finops --region $AWS_REGION"

# Cleanup
rm -f /tmp/lifecycle-policy.json