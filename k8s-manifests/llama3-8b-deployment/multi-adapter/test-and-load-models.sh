#!/bin/bash
# Complete Testing and Model Loading Script for Llama3 Multi-Adapter Deployment
set -euo pipefail

NAMESPACE="llama3-multi-adapter"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 Llama3 Multi-Adapter Test & Setup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ===================================================
# STEP 1: Test Pod Connectivity
# ===================================================
echo -e "${YELLOW}📡 Step 1: Testing Pod Connectivity...${NC}"
echo ""

PODS=$(kubectl get pods -n $NAMESPACE --no-headers | awk '{print $1}')

for pod in $PODS; do
    status=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$status" == "Running" ]; then
        echo -e "${GREEN}✅ $pod: Running${NC}"
    else
        echo -e "${RED}❌ $pod: $status${NC}"
    fi
done

echo ""

# ===================================================
# STEP 2: Test Services
# ===================================================
echo -e "${YELLOW}🌐 Step 2: Testing Services...${NC}"
echo ""

SERVICES=$(kubectl get svc -n $NAMESPACE --no-headers | awk '{print $1}')

for svc in $SERVICES; do
    cluster_ip=$(kubectl get svc $svc -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    port=$(kubectl get svc $svc -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    echo -e "${BLUE}Service: $svc${NC}"
    echo "  ClusterIP: $cluster_ip:$port"
done

echo ""

# ===================================================
# STEP 3: Load Llama3 8B Model into Base Pod
# ===================================================
echo -e "${YELLOW}📦 Step 3: Loading Llama3 8B Model into Base Pod...${NC}"
echo ""

echo "🔄 Pulling llama3:8b model (this may take 5-10 minutes)..."
kubectl exec -n $NAMESPACE deployment/ollama-base -- ollama pull llama3:8b &
BASE_PID=$!

echo "⏳ Waiting for base model download..."
wait $BASE_PID

echo -e "${GREEN}✅ Base model loaded${NC}"
echo ""

# Verify base model
echo "📋 Verifying base model..."
kubectl exec -n $NAMESPACE deployment/ollama-base -- ollama list

echo ""

# ===================================================
# STEP 4: Load Model into Chatbot Adapter
# ===================================================
echo -e "${YELLOW}💬 Step 4: Loading Model into Chatbot Adapter...${NC}"
echo ""

echo "🔄 Pulling llama3:8b into chatbot adapter..."
kubectl exec -n $NAMESPACE deployment/ollama-adapter-chatbot -- ollama pull llama3:8b &
CHAT_PID=$!

echo "⏳ Waiting for chatbot model download..."
wait $CHAT_PID

echo -e "${GREEN}✅ Chatbot adapter model loaded${NC}"
echo ""

# Verify chatbot model
echo "📋 Verifying chatbot model..."
kubectl exec -n $NAMESPACE deployment/ollama-adapter-chatbot -- ollama list

echo ""

# ===================================================
# STEP 5: Test Model Inference (Base)
# ===================================================
echo -e "${YELLOW}🧪 Step 5: Testing Base Model Inference...${NC}"
echo ""

echo "Sending test prompt to base model..."
BASE_RESPONSE=$(kubectl exec -n $NAMESPACE deployment/ollama-base -- \
    curl -s http://localhost:11434/api/generate -d '{
        "model": "llama3:8b",
        "prompt": "Say hello in one sentence.",
        "stream": false
    }' | jq -r '.response' 2>/dev/null || echo "Error: No response")

if [ "$BASE_RESPONSE" != "Error: No response" ] && [ -n "$BASE_RESPONSE" ]; then
    echo -e "${GREEN}✅ Base Model Response:${NC}"
    echo "$BASE_RESPONSE" | head -c 200
    echo ""
else
    echo -e "${RED}❌ Base model inference failed${NC}"
fi

echo ""

# ===================================================
# STEP 6: Test Model Inference (Chatbot)
# ===================================================
echo -e "${YELLOW}💬 Step 6: Testing Chatbot Adapter Inference...${NC}"
echo ""

echo "Sending test prompt to chatbot adapter..."
CHAT_RESPONSE=$(kubectl exec -n $NAMESPACE deployment/ollama-adapter-chatbot -- \
    curl -s http://localhost:11434/api/generate -d '{
        "model": "llama3:8b",
        "prompt": "Introduce yourself as a helpful AI assistant in one sentence.",
        "stream": false
    }' | jq -r '.response' 2>/dev/null || echo "Error: No response")

if [ "$CHAT_RESPONSE" != "Error: No response" ] && [ -n "$CHAT_RESPONSE" ]; then
    echo -e "${GREEN}✅ Chatbot Adapter Response:${NC}"
    echo "$CHAT_RESPONSE" | head -c 200
    echo ""
else
    echo -e "${RED}❌ Chatbot adapter inference failed${NC}"
fi

echo ""

# ===================================================
# STEP 7: Test HTTPS Endpoints (via port-forward)
# ===================================================
echo -e "${YELLOW}🔐 Step 7: Testing HTTPS Endpoints...${NC}"
echo ""

echo "Note: Testing via port-forward (ingress may require DNS configuration)"
echo ""

# Test base model via port-forward
echo "Testing base model endpoint..."
kubectl port-forward -n $NAMESPACE svc/ollama-base 11434:11434 >/dev/null 2>&1 &
PF_BASE=$!
sleep 2

BASE_API=$(curl -s http://localhost:11434/api/tags 2>/dev/null || echo '{"error": "failed"}')
kill $PF_BASE 2>/dev/null || true

if echo "$BASE_API" | grep -q "llama3:8b"; then
    echo -e "${GREEN}✅ Base model API responding${NC}"
else
    echo -e "${RED}❌ Base model API not responding properly${NC}"
fi

echo ""

# Test chatbot adapter via port-forward
echo "Testing chatbot adapter endpoint..."
kubectl port-forward -n $NAMESPACE svc/ollama-chatbot 11435:11434 >/dev/null 2>&1 &
PF_CHAT=$!
sleep 2

CHAT_API=$(curl -s http://localhost:11435/api/tags 2>/dev/null || echo '{"error": "failed"}')
kill $PF_CHAT 2>/dev/null || true

if echo "$CHAT_API" | grep -q "llama3:8b"; then
    echo -e "${GREEN}✅ Chatbot adapter API responding${NC}"
else
    echo -e "${RED}❌ Chatbot adapter API not responding properly${NC}"
fi

echo ""

# ===================================================
# STEP 8: Test Qdrant Vector DB
# ===================================================
echo -e "${YELLOW}🗄️  Step 8: Testing Qdrant Vector Database...${NC}"
echo ""

kubectl port-forward -n $NAMESPACE svc/qdrant-api 6333:6333 >/dev/null 2>&1 &
PF_QDRANT=$!
sleep 2

QDRANT_HEALTH=$(curl -s http://localhost:6333/health 2>/dev/null || echo '{"status": "error"}')
kill $PF_QDRANT 2>/dev/null || true

if echo "$QDRANT_HEALTH" | grep -q "ok"; then
    echo -e "${GREEN}✅ Qdrant is healthy${NC}"
    echo "Response: $QDRANT_HEALTH"
else
    echo -e "${RED}❌ Qdrant health check failed${NC}"
fi

echo ""

# ===================================================
# STEP 9: Generate Summary Report
# ===================================================
echo -e "${YELLOW}📊 Step 9: Generating Summary Report...${NC}"
echo ""

cat > /tmp/llama3-test-summary.md << EOF
# Llama3 Multi-Adapter Deployment Test Summary

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Namespace:** $NAMESPACE

---

## 🎯 Deployment Status

### Running Pods
\`\`\`
$(kubectl get pods -n $NAMESPACE)
\`\`\`

### Services
\`\`\`
$(kubectl get svc -n $NAMESPACE)
\`\`\`

---

## 📦 Loaded Models

### Base Model
\`\`\`
$(kubectl exec -n $NAMESPACE deployment/ollama-base -- ollama list 2>/dev/null)
\`\`\`

### Chatbot Adapter
\`\`\`
$(kubectl exec -n $NAMESPACE deployment/ollama-adapter-chatbot -- ollama list 2>/dev/null)
\`\`\`

---

## 🧪 Inference Tests

### Base Model Test
**Prompt:** "Say hello in one sentence."

**Response:**
\`\`\`
$BASE_RESPONSE
\`\`\`

### Chatbot Adapter Test
**Prompt:** "Introduce yourself as a helpful AI assistant in one sentence."

**Response:**
\`\`\`
$CHAT_RESPONSE
\`\`\`

---

## 🌐 Access Information

### Internal Cluster Access (via port-forward)

**Base Model:**
\`\`\`bash
kubectl port-forward -n $NAMESPACE svc/ollama-base 11434:11434
curl http://localhost:11434/api/generate -d '{"model":"llama3:8b","prompt":"Hello","stream":false}'
\`\`\`

**Chatbot Adapter:**
\`\`\`bash
kubectl port-forward -n $NAMESPACE svc/ollama-chatbot 11435:11434
curl http://localhost:11435/api/generate -d '{"model":"llama3:8b","prompt":"Hello","stream":false}'
\`\`\`

**Qdrant Vector DB:**
\`\`\`bash
kubectl port-forward -n $NAMESPACE svc/qdrant-api 6333:6333
curl http://localhost:6333/health
\`\`\`

### External Access (via Ingress with HTTPS)

**Note:** Requires DNS entry in /etc/hosts:
\`\`\`
10.0.228.180  llama3.daclab-ai.local
\`\`\`

**Endpoints:**
- Base: https://llama3.daclab-ai.local/base/
- Chatbot: https://llama3.daclab-ai.local/chatbot/
- Code: https://llama3.daclab-ai.local/code/ (when enabled)
- RAG: https://llama3.daclab-ai.local/rag/ (when enabled)
- Architecture: https://llama3.daclab-ai.local/architecture/ (when enabled)

---

## ✅ Next Steps

1. ✅ Models loaded and tested
2. ⏭️ Enable additional adapters when more GPUs available
3. ⏭️ Configure ingress routing for proper HTTPS access
4. ⏭️ Set up monitoring and metrics collection

---

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF

echo -e "${GREEN}✅ Summary report saved to: /tmp/llama3-test-summary.md${NC}"
cat /tmp/llama3-test-summary.md

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Testing and Setup Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "📋 Summary saved to: /tmp/llama3-test-summary.md"
echo "📊 View deployment: kubectl get all -n $NAMESPACE"
echo "💬 Test inference: kubectl exec -n $NAMESPACE deployment/ollama-adapter-chatbot -- ollama run llama3:8b"
echo ""
