#!/bin/bash
set -euo pipefail

echo "🔐 Setting up cert-manager for automated SSL certificates"
echo "=========================================================="
echo ""

# Check if cert-manager is already installed
if kubectl get namespace cert-manager &>/dev/null; then
    echo "✅ cert-manager namespace already exists"
else
    echo "📦 Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    echo "⏳ Waiting for cert-manager pods to be ready..."
    kubectl wait --for=condition=Available \
        deployment/cert-manager \
        deployment/cert-manager-webhook \
        deployment/cert-manager-cainjector \
        -n cert-manager \
        --timeout=300s
    
    echo "✅ cert-manager installed successfully"
fi

echo ""
echo "📋 cert-manager status:"
kubectl get pods -n cert-manager
echo ""

echo "✅ cert-manager setup complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Configure ClusterIssuer: kubectl apply -f ../ssl/cluster-issuer.yaml"
echo "  2. Update ingress with TLS: kubectl apply -f ../ssl/ingress-tls.yaml"
echo "  3. Verify certificate: kubectl get certificate -n llama3-multi-adapter"
