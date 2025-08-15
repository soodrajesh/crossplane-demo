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

# Start minikube with adequate resources for Crossplane
minikube start --driver=docker --memory=6144 --cpus=4 --disk-size=20g

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Verify cluster is running
minikube status
kubectl cluster-info
kubectl get nodes
```

### 2. Configure kubectl Context

```bash
# Ensure kubectl is pointing to minikube
kubectl config current-context
# Should show: minikube

# If not, set context
kubectl config use-context minikube

# Verify cluster access
kubectl get namespaces
kubectl get pods --all-namespaces
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

# Install Crossplane with proper configuration
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --wait

# Verify Crossplane installation
kubectl get pods -n crossplane-system
kubectl get crd | grep crossplane

# Wait for Crossplane to be fully ready
kubectl wait --for=condition=ready pod -l app=crossplane --namespace crossplane-system --timeout=300s
```

### Step 3: Install AWS Provider

```bash
# Apply AWS provider configuration
kubectl apply -f config/providers/aws-provider.yaml

# Monitor provider installation
kubectl get providers
kubectl describe provider provider-aws

# Wait for provider to be healthy (this may take 5-10 minutes)
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-aws --timeout=600s

# Verify provider CRDs are installed
kubectl get crd | grep aws
```

### Step 4: Configure AWS Credentials

```bash
# Create AWS credentials secret using your raj-private profile
aws configure list --profile raj-private

# Extract credentials and create secret
kubectl create secret generic aws-creds -n crossplane-system \
  --from-literal=creds="[default]
aws_access_key_id = $(aws configure get aws_access_key_id --profile raj-private)
aws_secret_access_key = $(aws configure get aws_secret_access_key --profile raj-private)
region = eu-west-1"

# Verify secret creation
kubectl get secret aws-creds -n crossplane-system

# Apply ProviderConfig
kubectl apply -f config/aws/provider-config.yaml

# Verify ProviderConfig
kubectl get providerconfig
kubectl describe providerconfig default
```

### Step 5: Deploy Infrastructure

```bash
# Deploy infrastructure in dependency order

# 1. VPC and networking (using existing infrastructure)
echo "Deploying VPC and networking..."
kubectl apply -f config/infrastructure/vpc.yaml
kubectl apply -f config/infrastructure/subnets.yaml

# Wait for VPC to be ready
kubectl wait --for=condition=ready vpc.ec2.aws.crossplane.io/crossplane-demo-vpc --timeout=300s

# 2. Security groups
echo "Deploying security groups..."
kubectl apply -f config/infrastructure/security-groups.yaml
kubectl apply -f config/infrastructure/db-security-group.yaml

# 3. RDS components
echo "Deploying RDS infrastructure..."
kubectl apply -f config/infrastructure/rds-secret.yaml
kubectl apply -f config/infrastructure/rds-subnet-group.yaml

# Wait for subnet group
kubectl wait --for=condition=ready dbsubnetgroup.rds.aws.crossplane.io/crossplane-demo-subnet-group --timeout=300s

# Deploy RDS instance (this takes 10-15 minutes)
echo "Deploying RDS instance (this will take 10-15 minutes)..."
kubectl apply -f config/infrastructure/rds-instance.yaml

# 4. S3 bucket
echo "Deploying S3 bucket..."
kubectl apply -f config/infrastructure/s3-bucket.yaml
```

### Step 6: Deploy Sample Application

```bash
# Create namespace for sample application
kubectl create namespace sample-app --dry-run=client -o yaml | kubectl apply -f -

# Deploy the sample application
kubectl apply -f config/applications/sample-app.yaml

# Wait for application to be ready
kubectl wait --for=condition=ready pod -l app=sample-app -n sample-app --timeout=300s

# Check application status
kubectl get all -n sample-app
kubectl get pods -n sample-app -o wide
kubectl get svc -n sample-app

# Check application logs
kubectl logs -l app=sample-app -n sample-app
```

### Step 7: Access the Application on Minikube

```bash
# Method 1: Port-forward (recommended for testing)
kubectl port-forward -n sample-app svc/sample-app-service 8080:80 &

# Test the application
curl http://localhost:8080
open http://localhost:8080  # macOS - opens in browser

# Method 2: Minikube service (gets external URL)
minikube service sample-app-service -n sample-app --url

# Method 3: Minikube tunnel (for LoadBalancer services)
# Run in separate terminal
minikube tunnel

# Then check external IP
kubectl get svc -n sample-app

# Stop port-forward when done
killall kubectl  # or use Ctrl+C in the port-forward terminal
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

### Stop Minikube

```bash
# Stop the minikube cluster
minikube stop

# Check cluster status
minikube status

# Start cluster again when needed
minikube start

# Delete cluster entirely (fresh start)
minikube delete

# View all minikube profiles
minikube profile list
```

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
