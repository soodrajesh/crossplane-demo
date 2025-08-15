#!/bin/bash

# Crossplane Demo Installation Script
# This script installs Crossplane and configures the demo environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# AWS Configuration
AWS_PROFILE="raj-private"
AWS_REGION="eu-west-1"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("aws")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check Kubernetes cluster
check_kubernetes() {
    print_status "Checking Kubernetes cluster..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Kubernetes cluster is not accessible"
        print_status "Please ensure your cluster is running and kubectl is configured"
        exit 1
    fi
    
    print_success "Kubernetes cluster is accessible"
}

# Function to install Crossplane
install_crossplane() {
    print_status "Installing Crossplane..."
    
    # Add Crossplane Helm repository
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    
    # Install Crossplane
    helm install crossplane crossplane-stable/crossplane \
        --namespace crossplane-system \
        --create-namespace \
        --wait \
        --timeout 5m
    
    print_success "Crossplane installed successfully"
}

# Function to wait for Crossplane to be ready
wait_for_crossplane() {
    print_status "Waiting for Crossplane to be ready..."
    
    kubectl wait --for=condition=Available --timeout=300s deployment/crossplane -n crossplane-system
    kubectl wait --for=condition=Available --timeout=300s deployment/crossplane-rbac-manager -n crossplane-system
    
    print_success "Crossplane is ready"
}

# Function to install AWS provider
install_aws_provider() {
    print_status "Installing AWS provider..."
    
    kubectl apply -f config/providers/aws-provider.yaml
    
    # Wait for provider to be ready
    kubectl wait provider.pkg.crossplane.io/provider-aws --for=condition=Healthy --timeout=5m
    
    print_success "AWS provider installed successfully"
}

# Function to configure AWS credentials
configure_aws_credentials() {
    print_status "Configuring AWS credentials for profile: $AWS_PROFILE..."
    
    # Create credentials file with profile
    mkdir -p config/aws
    cat > config/aws/aws-credentials.txt << EOF
[$AWS_PROFILE]
aws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)
aws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)
region = $AWS_REGION
EOF
    
    # Create secret
    kubectl create secret generic aws-creds \
        --from-file=creds=config/aws/aws-credentials.txt \
        -n crossplane-system \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Clean up credentials file
    rm -f config/aws/aws-credentials.txt
    
    print_success "AWS credentials configured for profile: $AWS_PROFILE"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure in region: $AWS_REGION..."
    
    # Deploy in dependency order
    print_status "Deploying VPC (existing)..."
    kubectl apply -f config/infrastructure/vpc.yaml
    
    print_status "Deploying subnets (existing)..."
    kubectl apply -f config/infrastructure/subnets.yaml
    
    print_status "Deploying security groups..."
    kubectl apply -f config/infrastructure/security-groups.yaml
    kubectl apply -f config/infrastructure/db-security-group.yaml
    
    print_status "Deploying RDS subnet group..."
    kubectl apply -f config/infrastructure/rds-subnet-group.yaml
    
    print_status "Deploying RDS secret..."
    kubectl apply -f config/infrastructure/rds-secret.yaml
    
    print_status "Deploying S3 bucket..."
    kubectl apply -f config/infrastructure/s3-bucket.yaml
    
    print_status "Deploying RDS instance..."
    kubectl apply -f config/infrastructure/rds-instance.yaml
    
    print_success "Infrastructure deployment initiated"
}

# Function to deploy sample application
deploy_sample_app() {
    print_status "Deploying sample application..."
    
    # Apply sample application
    kubectl apply -f config/applications/
    
    print_success "Sample application deployment initiated"
}

# Main installation function
main() {
    echo "🚀 Crossplane Demo Installation (Ireland Region)"
    echo "================================================"
    echo "AWS Profile: $AWS_PROFILE"
    echo "AWS Region: $AWS_REGION"
    echo "================================================"
    
    check_prerequisites
    check_kubernetes
    install_crossplane
    wait_for_crossplane
    install_aws_provider
    configure_aws_credentials
    deploy_infrastructure
    deploy_sample_app
    
    print_success "Installation completed successfully!"
    print_status "Run './scripts/validate.sh' to verify the setup"
}

# Run main function
main "$@"
