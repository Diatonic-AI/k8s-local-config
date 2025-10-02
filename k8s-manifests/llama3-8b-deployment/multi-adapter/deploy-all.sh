#!/bin/bash
set -euo pipefail

# Master deployment script for Llama3 Multi-Adapter System
# This script deploys all components in the correct order with health checks

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'

log_info() { echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}"; }
log_success() { echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"; }
log_warning() { echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"; }
log_error() { echo -e "${COLOR_RED}❌ $1${COLOR_RESET}"; }

# Verify kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
fi

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    log_info "Waiting for pods with label $label in namespace $namespace..."
    
    if kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null; then
        log_success "Pods are ready"
        return 0
    else
        log_warning "Some pods may not be ready yet"
        return 1
    fi
}

# Function to check deployment health
check_deployment() {
    local namespace=$1
    local deployment=$2
    
    local ready=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [ "$ready" == "$desired" ] && [ "$ready" != "0" ]; then
        log_success "$deployment: $ready/$desired replicas ready"
        return 0
    else
        log_warning "$deployment: $ready/$desired replicas ready"
        return 1
    fi
}

echo "======================================================================="
echo "🚀 Llama3 Multi-Adapter Deployment"
echo "======================================================================="
echo ""

# Phase 1: GPU Time-Slicing
echo "📊 Phase 1: GPU Time-Slicing Configuration"
echo "-----------------------------------------------------------------------"
log_info "Applying GPU time-slicing configuration..."
kubectl apply -f k8s/gpu/gpu-time-slicing-config.yaml

log_info "Deploying NVIDIA device plugin with time-slicing..."
kubectl apply -f k8s/gpu/nvidia-device-plugin-timeslice.yaml

log_info "Waiting for device plugin to restart..."
sleep 30

# Verify GPU resources
log_info "Verifying GPU resources..."
gpu_count=$(kubectl get nodes -o json | jq -r '.items[].status.allocatable."nvidia.com/gpu"' | head -1)
log_success "Available GPUs: $gpu_count (should be 8 with time-slicing)"

echo ""
echo "📦 Phase 2: Storage and Namespace"
echo "-----------------------------------------------------------------------"
log_info "Creating namespace..."
kubectl apply -f k8s/storage/namespace.yaml

log_info "Creating PersistentVolumeClaims..."
kubectl apply -f k8s/storage/pvc-base-model.yaml
kubectl apply -f k8s/storage/pvc-adapters.yaml
kubectl apply -f k8s/storage/pvc-vector-db.yaml

log_info "Waiting for PVCs to be bound..."
sleep 10
kubectl get pvc -n llama3-multi-adapter

echo ""
echo "🧠 Phase 3: Base Model Deployment"
echo "-----------------------------------------------------------------------"
log_info "Deploying base model..."
kubectl apply -f k8s/base-model/deployment.yaml
kubectl apply -f k8s/base-model/service.yaml

wait_for_pods "llama3-multi-adapter" "app=llama3-base-model" 600
check_deployment "llama3-multi-adapter" "llama3-base-model"

echo ""
echo "🗄️ Phase 4: Qdrant Vector Database"
echo "-----------------------------------------------------------------------"
log_info "Deploying Qdrant vector database..."
kubectl apply -f k8s/qdrant/configmap.yaml
kubectl apply -f k8s/qdrant/statefulset.yaml
kubectl apply -f k8s/qdrant/service.yaml

wait_for_pods "llama3-multi-adapter" "app=qdrant" 180

# Test Qdrant connectivity
log_info "Testing Qdrant connectivity..."
if kubectl exec -n llama3-multi-adapter -it $(kubectl get pod -n llama3-multi-adapter -l app=qdrant -o jsonpath='{.items[0].metadata.name}') -- curl -s http://localhost:6333 > /dev/null; then
    log_success "Qdrant is responding"
else
    log_warning "Qdrant may not be fully ready yet"
fi

echo ""
echo "🤖 Phase 5: Adapter Deployments"
echo "-----------------------------------------------------------------------"

# Deploy Chatbot Adapter
log_info "Deploying Chatbot Adapter..."
kubectl apply -f k8s/adapters/chatbot/configmap.yaml
kubectl apply -f k8s/adapters/chatbot/deployment.yaml
kubectl apply -f k8s/adapters/chatbot/service.yaml

# Deploy Code Adapter
log_info "Deploying Code Generation Adapter..."
kubectl apply -f k8s/adapters/code/configmap.yaml
kubectl apply -f k8s/adapters/code/deployment.yaml
kubectl apply -f k8s/adapters/code/service.yaml

# Deploy RAG Adapter
log_info "Deploying RAG Adapter..."
kubectl apply -f k8s/adapters/rag/configmap.yaml
kubectl apply -f k8s/adapters/rag/service.yaml

# Note: RAG deployment needs to be created separately or via generate script
if [ -f "k8s/adapters/rag/deployment.yaml" ]; then
    kubectl apply -f k8s/adapters/rag/deployment.yaml
else
    log_warning "RAG deployment.yaml not found, skipping..."
fi

# Deploy Microservices Adapter (if exists)
if [ -f "k8s/adapters/microservices/deployment.yaml" ]; then
    log_info "Deploying Microservices Architecture Adapter..."
    kubectl apply -f k8s/adapters/microservices/
else
    log_warning "Microservices adapter not found, skipping..."
fi

log_info "Waiting for adapters to initialize (this may take 5-10 minutes)..."
sleep 120

# Check adapter status
echo ""
log_info "Checking adapter deployments..."
check_deployment "llama3-multi-adapter" "llama3-chatbot-adapter" || true
check_deployment "llama3-multi-adapter" "llama3-code-adapter" || true
check_deployment "llama3-multi-adapter" "llama3-rag-adapter" || true

echo ""
echo "🌐 Phase 6: Ingress Configuration"
echo "-----------------------------------------------------------------------"
log_info "Deploying Nginx Ingress..."
kubectl apply -f k8s/ingress/ingress.yaml

log_info "Waiting for ingress to be ready..."
sleep 10

echo ""
echo "======================================================================="
echo "🎉 Deployment Complete!"
echo "======================================================================="
echo ""

# Display deployment summary
echo "📊 Deployment Summary:"
echo "-----------------------------------------------------------------------"
kubectl get pods -n llama3-multi-adapter
echo ""
kubectl get svc -n llama3-multi-adapter
echo ""
kubectl get ingress -n llama3-multi-adapter
echo ""

# Health check URLs
echo "🔗 Health Check URLs (internal cluster):"
echo "-----------------------------------------------------------------------"
echo "  Base Model:          http://llama3-base-model.llama3-multi-adapter.svc.cluster.local:8080/health"
echo "  Chatbot Adapter:     http://llama3-chatbot-adapter.llama3-multi-adapter.svc.cluster.local:8080/health"
echo "  Code Adapter:        http://llama3-code-adapter.llama3-multi-adapter.svc.cluster.local:8080/health"
echo "  RAG Adapter:         http://llama3-rag-adapter.llama3-multi-adapter.svc.cluster.local:8080/health"
echo "  Qdrant:              http://qdrant-api.llama3-multi-adapter.svc.cluster.local:6333"
echo ""

# External URLs (if ingress configured)
echo "🌍 External URLs (via Ingress):"
echo "-----------------------------------------------------------------------"
INGRESS_HOST=$(kubectl get ingress llama3-multi-adapter-ingress -n llama3-multi-adapter -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "your-domain.com")
echo "  Base:                https://$INGRESS_HOST/base/health"
echo "  Chatbot:             https://$INGRESS_HOST/chatbot/health"
echo "  Code:                https://$INGRESS_HOST/code/health"
echo "  RAG:                 https://$INGRESS_HOST/rag/health"
echo "  Architecture:        https://$INGRESS_HOST/architecture/health"
echo ""

log_warning "Note: Update ingress.yaml with your actual domain name for external access"
log_info "For SSL/TLS setup, run: ./k8s/ssl/setup-ssl.sh your-domain.com"

echo ""
echo "📝 Next Steps:"
echo "-----------------------------------------------------------------------"
echo "1. Monitor adapter initialization: kubectl logs -f -n llama3-multi-adapter -l component=adapter"
echo "2. Test endpoints using the health check URLs above"
echo "3. Configure SSL certificates if using external ingress"
echo "4. Set up monitoring and logging"
echo "5. Load test your adapters"
echo ""
echo "For troubleshooting, see: docs/TROUBLESHOOTING.md"
echo "======================================================================="
