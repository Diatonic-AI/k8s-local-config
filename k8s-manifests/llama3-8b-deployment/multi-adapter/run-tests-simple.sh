#!/usr/bin/env bash
# Simple test runner - streams output directly

NAMESPACE="llama3-multi-adapter"

echo "=========================================="
echo "  Llama3 K8s Deployment Test Suite"
echo "=========================================="
echo ""

# Test 1: Namespace
echo "✓ Test 1: Namespace Verification"
kubectl get namespace "$NAMESPACE" && echo "  PASS: Namespace exists" || echo "  FAIL: Namespace missing"
echo ""

# Test 2: Pods
echo "✓ Test 2: Pod Status"
kubectl get pods -n "$NAMESPACE" -o wide
echo ""

# Test 3: Services
echo "✓ Test 3: Services"
kubectl get svc -n "$NAMESPACE"
echo ""

# Test 4: Ollama Health Check
echo "✓ Test 4: Ollama Health Check"
POD=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
    echo "  Testing pod: $POD"
    kubectl exec -n "$NAMESPACE" "$POD" -- curl -sf http://localhost:11434/ && echo "  PASS: Ollama responding" || echo "  FAIL: Ollama not responding"
else
    echo "  SKIP: Ollama pod not found"
fi
echo ""

# Test 5: List Models
echo "✓ Test 5: Available Models"
if [ -n "$POD" ]; then
    kubectl exec -n "$NAMESPACE" "$POD" -- curl -sf http://localhost:11434/api/tags | jq -r '.models[] | "  - \(.name)"'
else
    echo "  SKIP: Ollama pod not found"
fi
echo ""

# Test 6: Hybrid Proxy Health
echo "✓ Test 6: Hybrid Proxy Health"
PROXY_POD=$(kubectl get pods -n "$NAMESPACE" -l app=hybrid-inference-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PROXY_POD" ]; then
    echo "  Testing pod: $PROXY_POD"
    kubectl exec -n "$NAMESPACE" "$PROXY_POD" -- curl -sf http://localhost:8080/health && echo "  PASS: Proxy responding" || echo "  FAIL: Proxy not responding"
else
    echo "  SKIP: Proxy pod not found"
fi
echo ""

# Test 7: Qdrant Health
echo "✓ Test 7: Qdrant Vector DB"
QDRANT_POD=$(kubectl get pods -n "$NAMESPACE" -l app=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$QDRANT_POD" ]; then
    echo "  Testing pod: $QDRANT_POD"
    kubectl exec -n "$NAMESPACE" "$QDRANT_POD" -- curl -sf http://localhost:6333/collections && echo "  PASS: Qdrant responding" || echo "  FAIL: Qdrant not responding"
else
    echo "  SKIP: Qdrant pod not found"
fi
echo ""

# Test 8: Simple Inference Test
echo "✓ Test 8: Simple Inference Test"
if [ -n "$POD" ]; then
    echo "  Sending test prompt..."
    RESPONSE=$(kubectl exec -n "$NAMESPACE" "$POD" -- curl -sf -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model": "llama3.2:3b", "prompt": "What is Kubernetes in one sentence?", "stream": false}' 2>/dev/null)
    
    if echo "$RESPONSE" | jq -e '.response' &>/dev/null; then
        echo "  PASS: Inference successful"
        echo "  Response:"
        echo "$RESPONSE" | jq -r '.response' | fold -w 70 | sed 's/^/    /'
    else
        echo "  FAIL: Inference failed"
    fi
else
    echo "  SKIP: Ollama pod not found"
fi
echo ""

# Test 9: Resource Usage
echo "✓ Test 9: Resource Utilization"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  SKIP: Metrics server not available"
echo ""

# Test 10: Recent Events
echo "✓ Test 10: Recent Events"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
echo ""

# Test 11: Configurations
echo "✓ Test 11: Configuration Resources"
echo "  ConfigMaps: $(kubectl get configmaps -n "$NAMESPACE" --no-headers | wc -l)"
echo "  Secrets: $(kubectl get secrets -n "$NAMESPACE" --no-headers | wc -l)"
echo "  PVCs: $(kubectl get pvc -n "$NAMESPACE" --no-headers | wc -l)"
echo ""

# Test 12: Deployments Status
echo "✓ Test 12: Deployment Status"
kubectl get deployments -n "$NAMESPACE" -o wide
echo ""

echo "=========================================="
echo "  Test Suite Complete"
echo "=========================================="
