#!/bin/bash
set -euo pipefail

NAMESPACE="llama3-multi-adapter"

echo "🔄 Rolling Back Multi-Adapter Deployment"
echo "========================================="
echo ""

read -p "Are you sure you want to rollback? This will delete all multi-adapter resources. (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Rollback cancelled"
  exit 0
fi

echo "🗑️  Deleting routing..."
kubectl delete -f /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter/routing/ --ignore-not-found
echo ""

echo "🗑️  Deleting adapters..."
kubectl delete -f /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter/adapters/ --recursive --ignore-not-found
echo ""

echo "🗑️  Deleting base model..."
kubectl delete -f /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter/base/ --ignore-not-found
echo ""

echo "⏳ Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app.kubernetes.io/part-of=ai-inference -n $NAMESPACE --timeout=120s 2>/dev/null || true
echo ""

echo "🗑️  Deleting storage..."
kubectl delete -f /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter/storage/ --ignore-not-found
echo ""

echo "🗑️  Deleting namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found
echo ""

echo "✅ Rollback complete!"
echo ""
echo "📋 To restore the old deployment:"
echo "  kubectl apply -f /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/ollama/"
