#!/bin/bash
# cert-manager Installation Script for Control Node
# Run this on the control node (10.0.228.180)

set -euo pipefail

CERT_MANAGER_VERSION="v1.13.3"
NAMESPACE="cert-manager"

echo "🔐 Installing cert-manager ${CERT_MANAGER_VERSION}..."

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install cert-manager CRDs
echo "📦 Installing cert-manager CRDs..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

# Install cert-manager
echo "📦 Installing cert-manager components..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

echo "✅ cert-manager installation complete!"

# Show status
kubectl get pods -n cert-manager
