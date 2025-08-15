#!/bin/bash

# Crossplane Demo Cleanup Script
# This script cleans up all resources created by the demo

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

# Function to confirm cleanup
confirm_cleanup() {
    echo
    print_warning "This will delete ALL resources created by the Crossplane demo!"
    print_warning "This includes:"
    echo "  - Security groups (app and database)"
    echo "  - S3 bucket"
    echo "  - RDS subnet group"
    echo "  - RDS instance"
    echo "  - Sample application"
    echo "  - Crossplane installation"
    echo
    print_warning "Note: Your existing VPC and subnets will NOT be deleted"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
}

# Function to delete sample application
delete_sample_app() {
    print_status "Deleting sample application..."
    
    kubectl delete -f ../config/applications/ --ignore-not-found=true
    
    print_success "Sample application deleted"
}

# Function to delete infrastructure in dependency order
delete_infrastructure() {
    print_status "Deleting infrastructure in dependency order..."
    
    # Delete RDS instance first (may take time) - run in background
    print_warning "Deleting RDS instance (this may take 10-15 minutes)..."
    kubectl delete -f ../config/infrastructure/rds-instance.yaml --ignore-not-found=true --wait=false
    
    # Delete other resources that don't depend on RDS
    print_status "Deleting S3 bucket..."
    kubectl delete -f ../config/infrastructure/s3-bucket.yaml --ignore-not-found=true
    
    # Delete security groups
    print_status "Deleting security groups..."
    kubectl delete -f ../config/infrastructure/security-groups.yaml --ignore-not-found=true
    kubectl delete -f ../config/infrastructure/db-security-group.yaml --ignore-not-found=true
    kubectl delete securitygroup.ec2.aws.crossplane.io/crossplane-demo-sg-db --ignore-not-found=true
    
    # Delete RDS subnet group (wait a bit for RDS to start deleting)
    print_status "Deleting RDS subnet group..."
    kubectl delete -f ../config/infrastructure/rds-subnet-group.yaml --ignore-not-found=true --wait=false
    
    # Delete subnets (existing - just remove from Crossplane management)
    print_status "Removing subnets from Crossplane management..."
    kubectl delete subnet.ec2.aws.crossplane.io/crossplane-demo-subnet-public-1 --ignore-not-found=true --timeout=30s || true
    kubectl delete subnet.ec2.aws.crossplane.io/crossplane-demo-subnet-public-2 --ignore-not-found=true --timeout=30s || true
    
    # Delete VPC (existing - just remove from Crossplane management)
    print_status "Removing VPC from Crossplane management..."
    kubectl delete vpc.ec2.aws.crossplane.io/crossplane-demo-vpc --ignore-not-found=true --timeout=30s || {
        print_warning "VPC deletion timed out - continuing with cleanup"
    }
    
    print_warning "RDS deletion continues in background (check AWS console)"
    print_success "Infrastructure deletion initiated"
}

# Function to delete secrets
delete_secrets() {
    print_status "Deleting secrets..."
    
    kubectl delete secret rds-password -n crossplane-system --ignore-not-found=true
    kubectl delete secret aws-creds -n crossplane-system --ignore-not-found=true
    
    print_success "Secrets deleted"
}

# Function to delete AWS provider
delete_aws_provider() {
    print_status "Deleting AWS provider..."
    
    kubectl delete -f ../config/providers/aws-provider.yaml --ignore-not-found=true
    
    print_success "AWS provider deleted"
}

# Function to uninstall Crossplane
uninstall_crossplane() {
    print_status "Uninstalling Crossplane..."
    
    helm uninstall crossplane -n crossplane-system --ignore-not-found=true
    
    # Delete namespace
    kubectl delete namespace crossplane-system --ignore-not-found=true
    
    print_success "Crossplane uninstalled"
}

# Main cleanup function
main() {
    echo "🧹 Crossplane Demo Cleanup (Ireland Region)"
    echo "==========================================="
    echo "AWS Profile: $AWS_PROFILE"
    echo "AWS Region: $AWS_REGION"
    echo "==========================================="
    
    confirm_cleanup
    delete_sample_app
    delete_infrastructure
    delete_secrets
    delete_aws_provider
    uninstall_crossplane
    
    print_success "Cleanup completed successfully!"
}

# Run main function
main "$@"
