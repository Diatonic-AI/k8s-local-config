#!/bin/bash
set -euo pipefail

NAMESPACE="llama3-multi-adapter"

echo "🧪 Testing Multi-Adapter Endpoints"
echo "==================================="
echo ""

# Test Base Model
echo "1️⃣  Testing Base Model (no adapter)..."
kubectl run test-base -n $NAMESPACE --rm -it --restart=Never --image=curlimages/curl -- \
  curl -X POST http://ollama-base:11434/api/tags || true
echo ""

# Test Chatbot Adapter
echo "2️⃣  Testing Chatbot Adapter..."
kubectl run test-chatbot -n $NAMESPACE --rm -it --restart=Never --image=curlimages/curl -- \
  curl -X POST http://ollama-chatbot:11434/api/tags || true
echo ""

# Test Code Adapter
echo "3️⃣  Testing Code Adapter..."
kubectl run test-code -n $NAMESPACE --rm -it --restart=Never --image=curlimages/curl -- \
  curl -X POST http://ollama-code:11434/api/tags || true
echo ""

# Test Summarization Adapter
echo "4️⃣  Testing Summarization Adapter..."
kubectl run test-summarization -n $NAMESPACE --rm -it --restart=Never --image=curlimages/curl -- \
  curl -X POST http://ollama-summarization:11434/api/tags || true
echo ""

echo "✅ All endpoint tests complete!"
echo ""
echo "📊 Service Status:"
kubectl get services -n $NAMESPACE
echo ""
echo "🎯 Pod Distribution:"
kubectl get pods -n $NAMESPACE -o wide --sort-by='{.spec.nodeName}'
