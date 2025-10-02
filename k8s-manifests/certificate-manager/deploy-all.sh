#!/bin/bash
# Complete cert-manager deployment script
# Deploy to control node: ssh daclab-k8s@10.0.228.180 < deploy-all.sh

set -euo pipefail

echo "🚀 Starting cert-manager deployment..."
echo "================================================"

# Step 1: Install cert-manager
echo ""
echo "📦 Step 1: Installing cert-manager..."
bash ./install-cert-manager.sh

# Step 2: Wait a bit for CRDs to be ready
echo ""
echo "⏳ Step 2: Waiting for CRDs to be registered..."
sleep 10

# Step 3: Apply ClusterIssuers
echo ""
echo "🔐 Step 3: Creating ClusterIssuers..."
kubectl apply -f ./cluster-issuer-selfsigned.yaml

# Step 4: Wait for ClusterIssuers to be ready
echo ""
echo "⏳ Step 4: Waiting for ClusterIssuers to be ready..."
sleep 5
kubectl get clusterissuer

# Step 5: Create Certificate for Llama3
echo ""
echo "📜 Step 5: Creating certificate for llama3.daclab-ai.local..."
kubectl apply -f ./llama3-certificate.yaml

# Step 6: Wait for certificate to be issued
echo ""
echo "⏳ Step 6: Waiting for certificate to be issued..."
kubectl wait --for=condition=ready certificate/llama3-tls-cert -n llama3-multi-adapter --timeout=120s || true

# Step 7: Verify installation
echo ""
echo "✅ Step 7: Verifying installation..."
echo ""
echo "📊 cert-manager pods:"
kubectl get pods -n cert-manager
echo ""
echo "🔐 ClusterIssuers:"
kubectl get clusterissuer
echo ""
echo "📜 Certificates:"
kubectl get certificate -n llama3-multi-adapter
echo ""
echo "🔑 TLS Secret:"
kubectl get secret llama3-tls-cert -n llama3-multi-adapter || echo "Secret not yet created"
echo ""

# Step 8: Check certificate details
echo "📋 Certificate details:"
kubectl describe certificate llama3-tls-cert -n llama3-multi-adapter || true

echo ""
echo "================================================"
echo "✅ cert-manager deployment complete!"
echo ""
echo "🌐 Your ingress should now use TLS with self-signed certificate"
echo "   Access: https://llama3.daclab-ai.local"
echo ""
echo "⚠️  Note: Self-signed certificates will show browser warnings"
echo "   This is normal for local development"
echo ""
