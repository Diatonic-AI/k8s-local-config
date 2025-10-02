# 🚀 Llama3 8B Multi-Adapter - Quick Start Guide

## ✅ Current Status: OPERATIONAL

**3/3 Core Services Running**
- ✅ Base Model (1 GPU)
- ✅ Chatbot Adapter (1 GPU)  
- ✅ Qdrant Vector DB

**GPU:** 2/2 allocated optimally | **Storage:** 180Gi bound | **Ingress:** Configured

---

## 📋 Quick Commands

### Check Status
```bash
kubectl get pods -n llama3-multi-adapter
kubectl get svc -n llama3-multi-adapter
kubectl describe node daclab-asus | grep "nvidia.com/gpu"
```

### View Logs
```bash
# Base model
kubectl logs -n llama3-multi-adapter -f deployment/ollama-base

# Chatbot adapter
kubectl logs -n llama3-multi-adapter -f deployment/ollama-adapter-chatbot

# Qdrant
kubectl logs -n llama3-multi-adapter -f statefulset/qdrant
```

### Test Services (Port Forward)
```bash
# Base model on localhost:11434
kubectl port-forward -n llama3-multi-adapter svc/ollama-base 11434:11434

# Chatbot on localhost:11435
kubectl port-forward -n llama3-multi-adapter svc/ollama-chatbot 11435:11434

# Qdrant on localhost:6333
kubectl port-forward -n llama3-multi-adapter svc/qdrant-api 6333:6333
```

### Load Models
```bash
# Pull llama3:8b (Q4 quantized, ~4.5GB)
kubectl exec -n llama3-multi-adapter -it deployment/ollama-base -- ollama pull llama3:8b

# Pull into chatbot adapter
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-chatbot -- ollama pull llama3:8b

# Check loaded models
kubectl exec -n llama3-multi-adapter deployment/ollama-base -- ollama list
```

---

## 🔧 Management

### Scale Adapters
```bash
# Enable code adapter (requires 3rd GPU or time-slicing)
kubectl scale deployment llama3-code-adapter -n llama3-multi-adapter --replicas=1

# Scale chatbot to 0 (disable)
kubectl scale deployment ollama-adapter-chatbot -n llama3-multi-adapter --replicas=0
```

### Restart Services
```bash
# Restart base model
kubectl rollout restart deployment/ollama-base -n llama3-multi-adapter

# Restart chatbot
kubectl rollout restart deployment/ollama-adapter-chatbot -n llama3-multi-adapter
```

---

## 🧪 Test Inference

### Base Model
```bash
# After port-forward to localhost:11434
curl http://localhost:11434/api/generate -d '{
  "model": "llama3:8b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

### Chatbot Adapter
```bash
# After port-forward to localhost:11435
curl http://localhost:11435/api/chat -d '{
  "model": "llama3:8b",
  "messages": [
    {"role": "user", "content": "Hello! How are you?"}
  ],
  "stream": false
}'
```

### Qdrant
```bash
# After port-forward to localhost:6333
curl http://localhost:6333/collections

# Create a test collection
curl -X PUT http://localhost:6333/collections/test -H 'Content-Type: application/json' -d '{
  "vectors": {"size": 384, "distance": "Cosine"}
}'
```

---

## 📊 Resource Usage

### Check GPU Allocation
```bash
kubectl describe node daclab-asus | grep -A 10 "Allocated resources:"
# Should show: nvidia.com/gpu: 2/2
```

### Check Memory Usage
```bash
kubectl top pods -n llama3-multi-adapter
```

### GPU Details from Pod
```bash
kubectl exec -n llama3-multi-adapter deployment/ollama-base -- nvidia-smi
```

---

## 🌐 Access via Ingress

**Host:** llama3.daclab-ai.local  
**Ports:** 80 (HTTP), 443 (HTTPS)

### Add to /etc/hosts
```bash
echo "10.0.228.180 llama3.daclab-ai.local" | sudo tee -a /etc/hosts
```

### Access URLs
```bash
# Base model
curl http://llama3.daclab-ai.local/base/api/tags

# Chatbot
curl http://llama3.daclab-ai.local/chat/api/tags

# Qdrant (if exposed)
curl http://llama3.daclab-ai.local/qdrant/collections
```

---

## 📚 Documentation

- **Full Guide:** `DEPLOYMENT-COMPLETED.md`
- **GPU Fix Details:** `GPU-ALLOCATION-FIXED.md`
- **Architecture:** `ARCHITECTURE.md`
- **Troubleshooting:** See main README.md

---

## ⚠️ Important Notes

1. **GPU Allocation:** Using 2/2 GPUs (optimal for current hardware)
2. **Models Not Pre-loaded:** You must pull models manually (see "Load Models" above)
3. **Code Adapter:** Disabled (0 replicas) - not enough GPUs
4. **RAG/Microservices:** Not deployed due to YAML syntax errors
5. **Quantization:** Use Q4/Q5/Q8 quantized models for best fit

---

**Last Updated:** 2025-10-02 11:42 UTC  
**Status:** 🟢 Operational and ready for inference
