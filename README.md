# Crossplane Demo Project

A comprehensive demonstration of Crossplane for Infrastructure as Code (IaC) using cost-effective AWS resources in Ireland region (eu-west-1).

## 🎯 Overview

This project demonstrates Crossplane's capabilities for managing cloud infrastructure using Kubernetes-native resources. We'll create a simple web application with a database, all managed through Crossplane using your existing AWS infrastructure.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Crossplane    │    │   Kubernetes    │    │      AWS        │
│   Controller    │───▶│   Cluster       │───▶│   Resources     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Custom        │    │   Sample        │    │   S3 Bucket     │
│   Resources     │    │   Application   │    │   RDS Instance  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

- Docker Desktop (for minikube)
- minikube installed and running
- kubectl configured
- AWS CLI configured with `raj-private` profile
- Helm 3.x
- Crossplane CLI (optional but recommended)

## 🐳 Minikube Setup

### 1. Install and Start Minikube

```bash
# Install minikube (macOS)
brew install minikube

# Start minikube with Docker driver
minikube start --driver=docker --memory=4096 --cpus=2

# Verify cluster is running
minikube status
kubectl cluster-info
```

### 2. Configure kubectl Context

```bash
# Ensure kubectl is pointing to minikube
kubectl config current-context
# Should show: minikube

# Check cluster nodes
kubectl get nodes
```

## 🚀 Complete Setup Guide

### Step 1: Verify Minikube is Running

```bash
# Check minikube status
minikube status

# Verify kubectl connectivity
kubectl get pods -A
```

### Step 2: Install Crossplane

```bash
# Add Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --wait
```

### Step 3: Install AWS Provider

```bash
# Install AWS Provider
kubectl apply -f config/providers/aws-provider.yaml

# Wait for provider to be ready
kubectl wait provider.pkg.crossplane.io/provider-aws --for=condition=Healthy --timeout=2m
```

### Step 4: Configure AWS Credentials

```bash
# Create AWS credentials secret (uses raj-private profile automatically)
# Note: The install script handles this automatically and removes credentials file
./scripts/install.sh
```

### Step 5: Deploy Infrastructure Components

```bash
# Deploy infrastructure in correct order
kubectl apply -f config/infrastructure/vpc.yaml
kubectl apply -f config/infrastructure/subnets.yaml
kubectl apply -f config/infrastructure/security-groups.yaml
kubectl apply -f config/infrastructure/db-security-group.yaml
kubectl apply -f config/infrastructure/rds-subnet-group.yaml
kubectl apply -f config/infrastructure/rds-secret.yaml
kubectl apply -f config/infrastructure/s3-bucket.yaml
kubectl apply -f config/infrastructure/rds-instance.yaml

# Wait for resources to be ready (RDS takes 10-15 minutes)
kubectl get managed
```

### Step 6: Deploy Sample Application

```bash
# Deploy the sample application
kubectl apply -f config/applications/
```

### Step 7: Access the Application on Minikube

```bash
# For minikube, use port-forward to access the app
kubectl port-forward -n sample-app svc/sample-app-service 8080:80

# Test the application
curl http://localhost:8080
# Or open in browser: http://localhost:8080

# Alternative: Get minikube service URL
minikube service sample-app-service -n sample-app --url
```

## 📁 Project Structure

```
crossplane-demo/
├── config/
│   ├── providers/           # Crossplane providers
│   ├── infrastructure/      # Infrastructure resources
│   ├── applications/        # Sample applications
│   └── aws/                # AWS configuration
├── scripts/
│   ├── install.sh          # Installation script
│   ├── cleanup.sh          # Cleanup script
│   └── validate.sh         # Validation script
├── docs/
│   ├── architecture.md     # Detailed architecture
│   └── troubleshooting.md  # Troubleshooting guide
├── examples/
│   ├── basic/              # Basic examples
│   └── advanced/           # Advanced examples
└── README.md
```

## 🧪 Testing & Verification

### 1. Run Comprehensive Validation

```bash
# Run the validation script
./scripts/validate.sh

# Expected output should show:
# ✅ Crossplane installation: Running
# ✅ AWS provider: Healthy
# ✅ AWS credentials: Working
# ✅ VPC management: Active
```

### 2. Check Infrastructure Status

```bash
# Check all managed resources
kubectl get managed

# Monitor RDS creation (takes 10-15 minutes)
kubectl get rdsinstance.database.aws.crossplane.io/crossplane-demo-rds

# Check S3 bucket
kubectl get bucket.s3.aws.crossplane.io/crossplane-demo-bucket-2024-ireland

# Verify in AWS console
aws s3 ls --profile raj-private --region eu-west-1
aws rds describe-db-instances --profile raj-private --region eu-west-1
```

### 3. Test Sample Application

```bash
# Check application pods
kubectl get pods -n sample-app

# Should show 2 nginx pods running:
# sample-app-xxx   1/1     Running   0          5m
# sample-app-yyy   1/1     Running   0          5m

# Test application via port-forward
kubectl port-forward -n sample-app svc/sample-app-service 8080:80

# In another terminal, test HTTP response
curl http://localhost:8080
# Should return nginx welcome page

# Or open in browser
open http://localhost:8080
```

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 1. RDS PostgreSQL Version Error
**Error**: `Cannot find version 13.7 for postgres`

**Solution**:
```bash
# Check available PostgreSQL versions
aws rds describe-db-engine-versions --engine postgres --region eu-west-1 --query 'DBEngineVersions[?contains(EngineVersion, `13.`)].EngineVersion' --output table --profile raj-private

# Update RDS configuration to use available version (e.g., 13.22)
# Edit config/infrastructure/rds-instance.yaml
# Change engineVersion: "13.7" to engineVersion: "13.22"

# Redeploy RDS
kubectl delete rdsinstance.database.aws.crossplane.io/crossplane-demo-rds
kubectl apply -f config/infrastructure/rds-instance.yaml
```

#### 2. RDS Username Reserved Word Error
**Error**: `MasterUsername admin cannot be used as it is a reserved word`

**Solution**:
```bash
# Update RDS configuration
# Edit config/infrastructure/rds-instance.yaml
# Change masterUsername: admin to masterUsername: dbuser

# Redeploy RDS
kubectl delete rdsinstance.database.aws.crossplane.io/crossplane-demo-rds
kubectl apply -f config/infrastructure/rds-instance.yaml
```

#### 3. Minikube LoadBalancer Pending
**Issue**: LoadBalancer services show `<pending>` external IP

**Solution**: Use port-forward or minikube tunnel
```bash
# Option 1: Port forward
kubectl port-forward -n sample-app svc/sample-app-service 8080:80

# Option 2: Minikube tunnel (requires sudo)
minikube tunnel
```

## 🧹 Cleanup

### Remove All Resources

```bash
# Run from project root
./scripts/cleanup.sh

# Or from scripts directory
cd scripts && bash cleanup.sh
```

**Note**: The cleanup script now uses correct relative paths and can be run from either the project root or the scripts directory.

## 📊 Monitoring

### Real-time Resource Monitoring

```bash
# Watch all managed resources
watch kubectl get managed

# Monitor specific resource types
kubectl get rdsinstance -w
kubectl get bucket -w
```

---

**Happy Crossplane-ing! 🚀**
