#!/bin/bash

# Crossplane Demo Validation Script
# This script validates the installation and configuration

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

# Function to check Crossplane installation
check_crossplane() {
    print_status "Checking Crossplane installation..."
    
    if kubectl get pods -n crossplane-system | grep -q "crossplane.*Running"; then
        print_success "Crossplane is running"
    else
        print_error "Crossplane is not running properly"
        return 1
    fi
}

# Function to check AWS provider
check_aws_provider() {
    print_status "Checking AWS provider..."
    
    if kubectl get provider.pkg.crossplane.io/provider-aws | grep -q "HEALTHY"; then
        print_success "AWS provider is healthy"
    else
        print_error "AWS provider is not healthy"
        return 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials for profile: $AWS_PROFILE..."
    
    if kubectl get secret aws-creds -n crossplane-system >/dev/null 2>&1; then
        print_success "AWS credentials secret exists"
        
        # Verify AWS credentials work
        if aws sts get-caller-identity --profile $AWS_PROFILE >/dev/null 2>&1; then
            local account_id=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
            print_success "AWS credentials working for account: $account_id"
        else
            print_warning "AWS credentials may not be working properly"
        fi
    else
        print_error "AWS credentials secret not found"
        return 1
    fi
}

# Function to check infrastructure resources
check_infrastructure() {
    print_status "Checking infrastructure resources..."
    
    local resources=(
        "vpc.ec2.aws.crossplane.io/crossplane-demo-vpc"
        "bucket.s3.aws.crossplane.io/crossplane-demo-bucket-2024-ireland"
        "rdsinstance.database.aws.crossplane.io/crossplane-demo-rds"
    )
    
    for resource in "${resources[@]}"; do
        if kubectl get "$resource" | grep -q "Ready"; then
            print_success "$resource is ready"
        else
            print_warning "$resource is not ready"
        fi
    done
}

# Function to check sample application
check_sample_app() {
    print_status "Checking sample application..."
    
    if kubectl get pods -n sample-app | grep -q "sample-app.*Running"; then
        print_success "Sample application is running"
    else
        print_warning "Sample application is not running"
    fi
    
    if kubectl get svc -n sample-app | grep -q "sample-app-service"; then
        print_success "Sample application service exists"
    else
        print_warning "Sample application service not found"
    fi
}

# Function to display resource status
display_status() {
    print_status "Displaying resource status..."
    
    echo
    echo "=== AWS Configuration ==="
    echo "Profile: $AWS_PROFILE"
    echo "Region: $AWS_REGION"
    echo "Account: $(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)"
    
    echo
    echo "=== Crossplane Resources ==="
    kubectl get managed 2>/dev/null || echo "No managed resources found"
    
    echo
    echo "=== Sample Application ==="
    kubectl get pods,svc -n sample-app 2>/dev/null || echo "Sample app namespace not found"
    
    echo
    echo "=== Crossplane Pods ==="
    kubectl get pods -n crossplane-system 2>/dev/null || echo "Crossplane namespace not found"
}

# Function to run all checks
run_validation() {
    echo "🔍 Crossplane Demo Validation (Ireland Region)"
    echo "=============================================="
    echo "AWS Profile: $AWS_PROFILE"
    echo "AWS Region: $AWS_REGION"
    echo "=============================================="
    
    local failed_checks=0
    
    check_crossplane || ((failed_checks++))
    check_aws_provider || ((failed_checks++))
    check_aws_credentials || ((failed_checks++))
    check_infrastructure
    check_sample_app
    display_status
    
    if [ $failed_checks -eq 0 ]; then
        print_success "All critical checks passed!"
    else
        print_warning "$failed_checks critical check(s) failed"
        print_status "Please review the errors above and fix them"
    fi
}

# Run validation
run_validation
