#!/bin/bash
set -euo pipefail

BASE_DIR="/home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter"

echo "🚀 Deploying Multi-Adapter Llama3 Architecture"
echo "================================================"
echo ""

# Phase 1: Namespace
echo "📦 Phase 1: Creating namespace..."
kubectl apply -f "$BASE_DIR/namespace.yaml"
echo "✅ Namespace created"
echo ""

# Phase 2: Storage
echo "💾 Phase 2: Creating storage..."
kubectl apply -f "$BASE_DIR/storage/"
echo "✅ Storage created"
echo ""
echo "⏳ Waiting for PVCs to be bound..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/llama3-base-models-pvc \
  pvc/llama3-chatbot-adapter-pvc \
  pvc/llama3-code-adapter-pvc \
  pvc/llama3-summarization-adapter-pvc \
  -n llama3-multi-adapter \
  --timeout=60s
echo "✅ All PVCs bound"
echo ""

# Phase 3: Base Model
echo "🏗️  Phase 3: Deploying base model..."
kubectl apply -f "$BASE_DIR/base/"
echo "✅ Base model deployment created"
echo ""
echo "⏳ Waiting for base model to be ready..."
kubectl wait --for=condition=Available \
  deployment/ollama-base \
  -n llama3-multi-adapter \
  --timeout=300s
echo "✅ Base model ready"
echo ""

# Phase 4: Adapters
echo "🎯 Phase 4: Deploying adapters..."
echo "  📱 Deploying chatbot adapter (3 replicas on GPU 0)..."
kubectl apply -f "$BASE_DIR/adapters/chatbot/"
echo "  💻 Deploying code adapter (2 replicas on GPU 1)..."
kubectl apply -f "$BASE_DIR/adapters/code/"
echo "  📝 Deploying summarization adapter (1 replica on GPU 1)..."
kubectl apply -f "$BASE_DIR/adapters/summarization/"
echo "✅ All adapters deployed"
echo ""

echo "⏳ Waiting for adapters to be ready..."
kubectl wait --for=condition=Available \
  deployment/ollama-adapter-chatbot \
  deployment/ollama-adapter-code \
  deployment/ollama-adapter-summarization \
  -n llama3-multi-adapter \
  --timeout=300s
echo "✅ All adapters ready"
echo ""

# Phase 5: Routing
echo "🔀 Phase 5: Setting up routing..."
kubectl apply -f "$BASE_DIR/routing/"
echo "✅ Routing configured"
echo ""

# Status Summary
echo "📊 Deployment Summary"
echo "===================="
echo ""
echo "Namespace:"
kubectl get namespace llama3-multi-adapter
echo ""
echo "Storage:"
kubectl get pvc -n llama3-multi-adapter
echo ""
echo "Deployments:"
kubectl get deployments -n llama3-multi-adapter
echo ""
echo "Services:"
kubectl get services -n llama3-multi-adapter
echo ""
echo "Pods:"
kubectl get pods -n llama3-multi-adapter -o wide
echo ""
echo "Ingress:"
kubectl get ingress -n llama3-multi-adapter
echo ""

echo "🎉 Multi-Adapter Deployment Complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Load base model: kubectl exec -n llama3-multi-adapter -it deployment/ollama-base -- ollama pull llama3:8b"
echo "  2. Test base endpoint: curl -X POST http://ollama-base.llama3-multi-adapter:11434/api/generate -d '{\"model\":\"llama3:8b\",\"prompt\":\"Hello\"}'"
echo "  3. Load adapters (example): kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-chatbot -- ollama pull <adapter-model>"
echo "  4. Test routing: ./scripts/test-adapters.sh"
echo "  5. Monitor resources: ./scripts/monitor.sh"
echo ""
echo "🔗 Service Endpoints:"
echo "  Base:           ollama-base.llama3-multi-adapter:11434"
echo "  Chatbot:        ollama-chatbot.llama3-multi-adapter:11434"
echo "  Code:           ollama-code.llama3-multi-adapter:11434"
echo "  Summarization:  ollama-summarization.llama3-multi-adapter:11434"
echo ""
echo "🌐 Ingress Paths (add to /etc/hosts: <node-ip> ollama.local):"
echo "  http://ollama.local/base"
echo "  http://ollama.local/chatbot"
echo "  http://ollama.local/code"
echo "  http://ollama.local/summarization"
