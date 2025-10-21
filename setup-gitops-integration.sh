#!/bin/bash

# DevOpsCanvas FinOps GitOps Integration Setup
set -e

echo "🔄 Setting up GitOps Integration for DevOpsCanvas FinOps"
echo "======================================================="

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

# Get repository owner
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
echo "Repository Owner: $REPO_OWNER"

# Check if GitOps repository exists
echo ""
echo -e "${BLUE}🔍 Checking GitOps repository...${NC}"

if gh repo view "$REPO_OWNER/devopscanvas-gitops" &> /dev/null; then
    echo -e "${GREEN}✅ GitOps repository exists: $REPO_OWNER/devopscanvas-gitops${NC}"
    
    # Check if we have write access
    REPO_PERMISSIONS=$(gh api repos/$REPO_OWNER/devopscanvas-gitops --jq '.permissions.push // false')
    
    if [ "$REPO_PERMISSIONS" = "true" ]; then
        echo -e "${GREEN}✅ Write access confirmed${NC}"
        
        # Clone and setup GitOps configuration
        echo ""
        echo -e "${BLUE}📋 Setting up GitOps configuration...${NC}"
        
        # Create temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        # Clone GitOps repository
        gh repo clone "$REPO_OWNER/devopscanvas-gitops"
        cd devopscanvas-gitops
        
        # Create applications directory if it doesn't exist
        mkdir -p applications
        
        # Create FinOps application configuration
        cat > applications/finops.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devopscanvas-finops
  namespace: argocd
  labels:
    app.kubernetes.io/name: devopscanvas-finops
    app.kubernetes.io/part-of: devopscanvas
spec:
  project: default
  source:
    repoURL: https://github.com/$REPO_OWNER/devopscanvas-finops
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: devopscanvas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

        # Create Kubernetes manifests directory
        mkdir -p k8s
        
        # Create basic Kubernetes deployment manifest
        cat > k8s/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devopscanvas-finops
  namespace: devopscanvas
  labels:
    app: devopscanvas-finops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: devopscanvas-finops
  template:
    metadata:
      labels:
        app: devopscanvas-finops
    spec:
      containers:
      - name: finops
        image: 211125552276.dkr.ecr.us-east-1.amazonaws.com/devopscanvas-finops:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: devopscanvas-finops-service
  namespace: devopscanvas
spec:
  selector:
    app: devopscanvas-finops
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
EOF

        # Commit and push changes
        git add .
        
        if git diff --staged --quiet; then
            echo -e "${YELLOW}⚠️ No changes to commit${NC}"
        else
            git commit -m "feat: add DevOpsCanvas FinOps GitOps configuration

- Add ArgoCD application configuration for FinOps service
- Add Kubernetes deployment and service manifests
- Configure automated sync and self-healing"
            
            git push origin main
            echo -e "${GREEN}✅ GitOps configuration pushed to repository${NC}"
        fi
        
        # Cleanup
        cd /
        rm -rf "$TEMP_DIR"
        
    else
        echo -e "${YELLOW}⚠️ No write access to GitOps repository${NC}"
        echo "Please ensure you have write permissions to $REPO_OWNER/devopscanvas-gitops"
    fi
    
else
    echo -e "${YELLOW}⚠️ GitOps repository does not exist${NC}"
    echo ""
    echo "Would you like to create the GitOps repository? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🚀 Creating GitOps repository...${NC}"
        
        # Create GitOps repository
        gh repo create "$REPO_OWNER/devopscanvas-gitops" \
            --description "DevOpsCanvas GitOps Configuration Repository" \
            --public \
            --clone
        
        cd devopscanvas-gitops
        
        # Create initial README
        cat > README.md << EOF
# DevOpsCanvas GitOps

This repository contains GitOps configurations for DevOpsCanvas services using ArgoCD.

## Structure

- \`applications/\` - ArgoCD Application definitions
- \`k8s/\` - Kubernetes manifests for services

## Services

- **DevOpsCanvas Portal** - Main developer portal
- **DevOpsCanvas FinOps** - Cost management and optimization
- **DevOpsCanvas GitOps** - GitOps automation
- **DevOpsCanvas Infrastructure** - Infrastructure as Code

## Usage

1. Install ArgoCD in your cluster
2. Apply the application configurations
3. ArgoCD will automatically sync and deploy services

## Getting Started

\`\`\`bash
# Apply all applications
kubectl apply -f applications/

# Or apply individual services
kubectl apply -f applications/finops.yaml
\`\`\`
EOF

        # Create applications directory and FinOps config
        mkdir -p applications k8s
        
        # Create the same configurations as above
        cat > applications/finops.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: devopscanvas-finops
  namespace: argocd
  labels:
    app.kubernetes.io/name: devopscanvas-finops
    app.kubernetes.io/part-of: devopscanvas
spec:
  project: default
  source:
    repoURL: https://github.com/$REPO_OWNER/devopscanvas-finops
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: devopscanvas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

        # Initial commit
        git add .
        git commit -m "feat: initial DevOpsCanvas GitOps repository

- Add README with repository structure
- Add DevOpsCanvas FinOps ArgoCD application
- Configure automated GitOps workflows"
        
        git push origin main
        
        echo -e "${GREEN}✅ GitOps repository created and configured${NC}"
        
        cd ..
        rm -rf devopscanvas-gitops
    else
        echo -e "${YELLOW}⚠️ GitOps repository creation skipped${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 GitOps integration setup complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "- GitOps Repository: $REPO_OWNER/devopscanvas-gitops"
echo "- FinOps Application: applications/finops.yaml"
echo "- Kubernetes Manifests: k8s/"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Install ArgoCD in your Kubernetes cluster"
echo "2. Apply the application configurations:"
echo "   kubectl apply -f applications/finops.yaml"
echo "3. Monitor deployments in ArgoCD UI"
echo ""
echo -e "${BLUE}🔄 Trigger New Deployment:${NC}"
echo "The next time you push to main branch, the GitOps workflow will:"
echo "- Update the image tag in the GitOps repository"
echo "- Create a pull request with the changes"
echo "- ArgoCD will automatically sync the changes"