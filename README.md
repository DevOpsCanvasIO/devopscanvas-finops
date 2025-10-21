# DevOpsCanvas FinOps Services

[![CI/CD Pipeline](https://github.com/DevOpsCanvasIO/devopscanvas-finops/actions/workflows/devopscanvas-finops-ci-cd.yml/badge.svg)](https://github.com/DevOpsCanvasIO/devopscanvas-finops/actions/workflows/devopscanvas-finops-ci-cd.yml)

DevOpsCanvas FinOps Services provide comprehensive cost management and optimization capabilities for cloud infrastructure, focusing on AWS environments.

## 🚀 Features

- **Cost Analysis**: Real-time cost tracking and analysis
- **Optimization Recommendations**: AI-powered cost optimization suggestions
- **Budget Management**: Automated budget monitoring and alerts
- **Resource Optimization**: Right-sizing recommendations for EC2, RDS, and other services
- **Cost Reporting**: Detailed cost reports and analytics
- **Multi-Account Support**: Centralized cost management across AWS accounts

## 🏗️ Architecture

The FinOps service is built as a microservice architecture with:

- **Node.js/TypeScript** backend
- **Express.js** REST API
- **AWS SDK** for cloud integration
- **Docker** containerization
- **AWS ECS** deployment
- **CloudWatch** logging and monitoring

## 🛠️ Development

### Prerequisites

- Node.js 18+
- Docker
- AWS CLI configured
- TypeScript

### Local Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build application
npm run build

# Run tests
npm test

# Lint code
npm run lint
```

### Environment Variables

```bash
NODE_ENV=development
PORT=3000
AWS_REGION=us-east-1
LOG_LEVEL=info
```

## 🚢 Deployment

### AWS ECS Deployment

The service automatically deploys to AWS ECS using GitHub Actions:

1. **Automatic Deployment**: Push to `main` branch triggers deployment
2. **Manual Deployment**: Use GitHub Actions workflow dispatch
3. **Multi-Registry**: Supports ECR, GHCR, and Docker Hub

### Infrastructure Setup

```bash
# Setup AWS infrastructure
./setup-aws-infrastructure.sh
```

This creates:
- ECR repository
- CloudWatch log group
- Verifies ECS cluster

### Manual Deployment

```bash
# Build and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 211125552276.dkr.ecr.us-east-1.amazonaws.com

docker build -t devopscanvas-finops .
docker tag devopscanvas-finops:latest 211125552276.dkr.ecr.us-east-1.amazonaws.com/devopscanvas-finops:latest
docker push 211125552276.dkr.ecr.us-east-1.amazonaws.com/devopscanvas-finops:latest
```

## 📊 API Endpoints

### Health Check
```
GET /health
```

### Cost Analysis
```
GET /api/costs
GET /api/costs/{accountId}
GET /api/costs/{accountId}/services
```

### Recommendations
```
GET /api/recommendations
GET /api/recommendations/{type}
POST /api/recommendations/generate
```

### Reports
```
GET /api/reports
GET /api/reports/{reportId}
POST /api/reports/generate
```

## 🔧 Configuration

### AWS Permissions

The service requires the following AWS permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetUsageReport",
        "ce:GetReservationCoverage",
        "ce:GetReservationPurchaseRecommendation",
        "ce:GetReservationUtilization",
        "ce:GetSavingsPlansUtilization",
        "ce:ListCostCategoryDefinitions",
        "ec2:DescribeInstances",
        "ec2:DescribeReservedInstances",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

### ECS Task Definition

The service runs on AWS ECS Fargate with:
- **CPU**: 512 units (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **Port**: 3000
- **Health Check**: `/health` endpoint

## 🔒 Security

- **Container Scanning**: Trivy security scans
- **Keyless Signing**: Cosign signatures
- **SBOM**: Software Bill of Materials
- **Least Privilege**: Minimal AWS permissions
- **Network Security**: VPC and security groups

## 📈 Monitoring

### CloudWatch Logs
- Log Group: `/ecs/devopscanvas-finops`
- Retention: 30 days
- Structured JSON logging

### Health Checks
- **ECS Health Check**: Container-level health monitoring
- **Application Health**: `/health` endpoint
- **Load Balancer**: Target group health checks

## 🔄 CI/CD Pipeline

The GitHub Actions pipeline includes:

1. **Testing**: Unit tests and linting
2. **Building**: Docker image build
3. **Security**: Vulnerability scanning
4. **Signing**: Keyless container signing
5. **Deployment**: AWS ECS deployment
6. **GitOps**: Automated GitOps PR creation

### Workflow Triggers

- **Push to main**: Full deployment
- **Pull Request**: Build and test only
- **Manual**: Configurable deployment options

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Create an issue in this repository
- Contact the DevOpsCanvas team
- Check the [documentation](https://docs.devopscanvas.io)

## 🔗 Related Projects

- [DevOpsCanvas Portal](https://github.com/DevOpsCanvasIO/devopscanvas-portal)
- [DevOpsCanvas GitOps](https://github.com/DevOpsCanvasIO/devopscanvas-gitops)
- [DevOpsCanvas Infrastructure](https://github.com/DevOpsCanvasIO/devopscanvas-infra)