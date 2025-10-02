#!/usr/bin/env bash
# Enhanced test runner using port-forward for API access

NAMESPACE="llama3-multi-adapter"

echo "=========================================="
echo "  Llama3 Enhanced Test Suite (Port-Forward)"
echo "=========================================="
echo ""

# Test 1: Check if ollama pod is ready
echo "✓ Test 1: Ollama Pod Ready Status"
POD=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
    STATUS=$(kubectl get pod -n "$NAMESPACE" "$POD" -o jsonpath='{.status.phase}')
    echo "  Pod: $POD"
    echo "  Status: $STATUS"
    
    if [ "$STATUS" = "Running" ]; then
        echo "  ✓ PASS: Ollama pod is running"
    else
        echo "  ✗ FAIL: Ollama pod not in Running state"
    fi
else
    echo "  ✗ FAIL: Ollama pod not found"
fi
echo ""

# Test 2: Port-forward test for Ollama
echo "✓ Test 2: Ollama API via Port-Forward"
if [ -n "$POD" ]; then
    echo "  Setting up port-forward..."
    kubectl port-forward -n "$NAMESPACE" "$POD" 11434:11434 &>/dev/null &
    PF_PID=$!
    sleep 3
    
    echo "  Testing health endpoint..."
    if curl -sf http://localhost:11434/ &>/dev/null; then
        echo "  ✓ PASS: Ollama API responding"
        
        echo "  Fetching available models..."
        MODELS=$(curl -sf http://localhost:11434/api/tags 2>/dev/null)
        if [ -n "$MODELS" ]; then
            echo "$MODELS" | jq -r '.models[] | "    - \(.name) (\(.size/1073741824 | floor)GB)"' 2>/dev/null || echo "    (Unable to parse models)"
        fi
    else
        echo "  ✗ FAIL: Ollama API not responding"
    fi
    
    kill $PF_PID 2>/dev/null
    wait $PF_PID 2>/dev/null
else
    echo "  SKIP: Ollama pod not found"
fi
echo ""

# Test 3: Inference Test
echo "✓ Test 3: Simple Inference Test"
if [ -n "$POD" ]; then
    echo "  Setting up port-forward..."
    kubectl port-forward -n "$NAMESPACE" "$POD" 11434:11434 &>/dev/null &
    PF_PID=$!
    sleep 3
    
    echo "  Sending test prompt: 'What is Kubernetes?'"
    START_TIME=$(date +%s%N)
    RESPONSE=$(curl -sf -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d '{"model": "llama3.2:3b", "prompt": "What is Kubernetes? Answer in one sentence.", "stream": false}' 2>/dev/null)
    END_TIME=$(date +%s%N)
    
    if echo "$RESPONSE" | jq -e '.response' &>/dev/null; then
        DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
        echo "  ✓ PASS: Inference successful (${DURATION}ms)"
        echo "  Response:"
        echo "$RESPONSE" | jq -r '.response' | fold -w 65 | sed 's/^/    /'
    else
        echo "  ✗ FAIL: Inference failed"
    fi
    
    kill $PF_PID 2>/dev/null
    wait $PF_PID 2>/dev/null
else
    echo "  SKIP: Ollama pod not found"
fi
echo ""

# Test 4: Qdrant via port-forward
echo "✓ Test 4: Qdrant Vector Database"
QDRANT_POD=$(kubectl get pods -n "$NAMESPACE" -l app=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$QDRANT_POD" ]; then
    echo "  Pod: $QDRANT_POD"
    echo "  Setting up port-forward..."
    kubectl port-forward -n "$NAMESPACE" "$QDRANT_POD" 6333:6333 &>/dev/null &
    PF_PID=$!
    sleep 3
    
    if curl -sf http://localhost:6333/collections &>/dev/null; then
        echo "  ✓ PASS: Qdrant API responding"
        COLLECTIONS=$(curl -sf http://localhost:6333/collections 2>/dev/null)
        COL_COUNT=$(echo "$COLLECTIONS" | jq -r '.result.collections | length' 2>/dev/null || echo "0")
        echo "  Collections: $COL_COUNT"
    else
        echo "  ✗ FAIL: Qdrant not responding"
    fi
    
    kill $PF_PID 2>/dev/null
    wait $PF_PID 2>/dev/null
else
    echo "  SKIP: Qdrant pod not found"
fi
echo ""

# Test 5: Resource utilization
echo "✓ Test 5: Resource Utilization"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "  SKIP: Metrics server not available"
echo ""

# Test 6: Pod readiness summary
echo "✓ Test 6: Pod Readiness Summary"
kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount
echo ""

# Test 7: Service endpoints
echo "✓ Test 7: Service Endpoints"
kubectl get endpoints -n "$NAMESPACE" | grep -E "(NAME|ollama|qdrant|hybrid)"
echo ""

echo "=========================================="
echo "  Test Suite Complete"
echo "=========================================="
