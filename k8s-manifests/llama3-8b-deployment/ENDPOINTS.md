# Llama3 8B Multi-Adapter Deployment - Endpoint Reference

**Last Updated:** 2025-10-02  
**Namespace:** `llama3-multi-adapter`  
**Cluster:** daclab-k8s (10.0.0.219)

---

## 🎯 Quick Access URLs

### Primary Services (Recommended)

| Service | ClusterIP Endpoint | Status | Description |
|---------|-------------------|--------|-------------|
| **Hybrid Proxy** | `http://10.107.148.186:8080` | ✅ Active | OpenAI-compatible API with local Ollama + HuggingFace fallback |
| **Ollama Direct** | `http://10.97.47.88:11434` | ✅ Active | Native Ollama API for llama3:8b model (GPU-accelerated) |
| **Qdrant Vector DB** | `http://10.101.86.126:6333` | ✅ Active | Vector database for RAG applications |

---

## 📦 All Deployments

### Active Deployments

| Deployment | Replicas | Image | Purpose |
|------------|----------|-------|---------|
| `hybrid-inference-proxy` | 2/2 | `python:3.11-slim` | API gateway with fallback routing |
| `ollama-simple-fast` | 1/1 | `ollama/ollama:latest` | GPU-accelerated Llama3 8B inference |

### Scaled Down (Available but not running)

| Deployment | Replicas | Image | Purpose |
|------------|----------|-------|---------|
| `llama3-vllm` | 0/0 | `vllm/vllm-openai:latest` | Advanced inference engine (requires model access) |
| `llama3-code-adapter` | 0/0 | `huggingface/transformers-pytorch-gpu:latest` | Code generation adapter |
| `llama3-microservices-adapter` | 0/0 | `ollama/ollama:latest` | Microservices-specific adapter |
| `llama3-rag-adapter` | 0/0 | `ollama/ollama:latest` | RAG pipeline adapter |

---

## 🔌 Service Endpoints (ClusterIP)

### Inference Services

```bash
# Hybrid Inference Proxy (OpenAI-compatible)
http://10.107.148.186:8080
  └─ /health              # Health check
  └─ /v1/models           # List models
  └─ /v1/chat/completions # Chat completions

# Ollama Simple Fast (Native Ollama API)
http://10.97.47.88:11434
  └─ /api/tags            # List models
  └─ /api/generate        # Generate completion
  └─ /api/chat            # Chat API

# Alternative Ollama Instances
http://10.98.229.99:11434     # ollama-base
http://10.96.121.250:11434    # ollama-base-centralized
http://10.101.189.119:11434   # ollama-chatbot
```

### Supporting Services

```bash
# Qdrant Vector Database
http://10.101.86.126:6333
  └─ /collections         # List collections
  └─ /collections/{name}  # Collection operations

# Adapter Proxy (Multi-adapter routing)
http://10.110.198.41:80
```

### Disabled Services

```bash
# vLLM (scaled to 0 - requires HuggingFace token and model access)
http://10.96.99.190:8000      # llama3-vllm

# Specialized Adapters (scaled to 0)
http://10.98.46.190:8080      # llama3-code-adapter
http://10.103.31.237:8080     # llama3-microservices-adapter  
http://10.111.193.148:8080    # llama3-rag-adapter
```

---

## 🌐 Ingress Endpoints

### Configured Ingresses

| Host | Address | Backend Service | TLS |
|------|---------|-----------------|-----|
| `ai.local` | 10.0.228.180 | hybrid-inference-proxy | ❌ Cert pending |
| `llama3.local` | 10.0.228.180 | hybrid-inference-proxy | ❌ Cert pending |
| `llama3.daclab-ai.local` | 10.0.228.180 | llama3-chatbot-adapter | ✅ Ready |
| `ollama-fast.local` | 10.0.228.180 | ollama-simple-fast | ❌ Cert pending |
| `vllm.local` | 10.0.228.180 | llama3-vllm | ❌ Cert pending |
| `llama3-vllm.local` | 10.0.228.180 | llama3-vllm | ❌ Cert pending |

**Note:** Ingress is configured with NodePort (30080/30443) but external access needs configuration.

---

## 🧪 Example Usage

### Using Hybrid Proxy (OpenAI-compatible)

```bash
# Health check
curl http://10.107.148.186:8080/health

# List models
curl http://10.107.148.186:8080/v1/models | jq .

# Chat completion
curl -X POST http://10.107.148.186:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "Explain quantum computing briefly"}],
    "max_tokens": 200,
    "temperature": 0.7
  }' | jq -r '.choices[0].message.content'
```

### Using Direct Ollama API

```bash
# List available models
curl http://10.97.47.88:11434/api/tags | jq -r '.models[].name'

# Generate completion (non-streaming)
curl -X POST http://10.97.47.88:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3:8b",
    "prompt": "Write a haiku about AI",
    "stream": false
  }' | jq -r '.response'

# Streaming generation
curl -X POST http://10.97.47.88:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3:8b",
    "prompt": "Write a short story about space exploration",
    "stream": true
  }' | while read line; do
    echo "$line" | jq -r '.response // empty' | tr -d '\n'
  done
```

### Using Qdrant Vector Database

```bash
# List collections
curl http://10.101.86.126:6333/collections | jq .

# Create a collection
curl -X PUT http://10.101.86.126:6333/collections/my_collection \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

---

## 🚀 Performance Metrics

### Ollama Simple Fast (GPU-Accelerated)

- **Hardware:** RTX 3080 (12GB) + RTX 2060 Super (8GB)
- **Model:** llama3:8b
- **Performance:**
  - Time to First Token (TTFT): ~230ms
  - Generation Speed: ~75 tokens/second
  - Inter-Token Latency: ~10ms
  - Average response time: 300-400ms for short queries

### Hybrid Proxy

- **Routing:** Local Ollama (primary) → HuggingFace Cloud (fallback)
- **Latency:** +20-50ms overhead for API translation
- **Success Rate:** 100% (with cloud fallback)

---

## 🔧 Management Commands

### Scale Services

```bash
# Scale Ollama to 2 replicas for higher availability
kubectl scale deployment ollama-simple-fast -n llama3-multi-adapter --replicas=2

# Enable vLLM (requires HuggingFace token configuration)
kubectl scale deployment llama3-vllm -n llama3-multi-adapter --replicas=1

# Enable specialized adapters
kubectl scale deployment llama3-code-adapter -n llama3-multi-adapter --replicas=1
kubectl scale deployment llama3-rag-adapter -n llama3-multi-adapter --replicas=1
```

### Check Logs

```bash
# Hybrid proxy logs
kubectl logs -n llama3-multi-adapter deployment/hybrid-inference-proxy -f

# Ollama logs
kubectl logs -n llama3-multi-adapter deployment/ollama-simple-fast -f

# Check GPU usage
kubectl exec -n llama3-multi-adapter deployment/ollama-simple-fast -- nvidia-smi
```

### Restart Services

```bash
# Restart hybrid proxy
kubectl rollout restart deployment hybrid-inference-proxy -n llama3-multi-adapter

# Restart Ollama
kubectl rollout restart deployment ollama-simple-fast -n llama3-multi-adapter
```

---

## 📝 Configuration Files

### Deployment Manifests

```
/home/daclab-ai/k8s-local-config/k8s-manifests/llama3-8b-deployment/
├── multi-adapter/
│   ├── hybrid-proxy-deployment.yaml    # Hybrid inference proxy
│   ├── ollama-simple-fast.yaml         # Fast Ollama deployment
│   ├── vllm-deployment.yaml            # vLLM configuration
│   └── qdrant-deployment.yaml          # Vector database
├── ingress/
│   └── llama3-ingress.yaml             # Ingress rules
└── secrets/
    └── huggingface-tokens.yaml         # HF API tokens
```

### Helper Scripts

```
/home/daclab-ai/bin/
└── llama-query                          # CLI query tool (in progress)
```

---

## 🐛 Troubleshooting

### Common Issues

**1. Connection Refused**
```bash
# Verify service is running
kubectl get pods -n llama3-multi-adapter

# Check service endpoints
kubectl get endpoints -n llama3-multi-adapter
```

**2. Slow Responses**
```bash
# Check GPU utilization
kubectl exec -n llama3-multi-adapter deployment/ollama-simple-fast -- nvidia-smi

# Check if model is loaded
curl http://10.97.47.88:11434/api/tags
```

**3. 404 Errors**
- Use ClusterIP endpoints directly (not ingress) for now
- Ensure you're using the correct API format (Ollama vs OpenAI-compatible)

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Ingress Layer                        │
│  (ai.local, llama3.local, ollama-fast.local) - NodePort     │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
┌─────────▼─────────┐         ┌─────────▼──────────┐
│  Hybrid Proxy (2) │         │ Ollama Direct (1)  │
│  10.107.148.186   │         │   10.97.47.88      │
│                   │         │                    │
│  - OpenAI API     │         │  - Native Ollama   │
│  - Auto fallback  │         │  - GPU Accelerated │
└─────────┬─────────┘         └─────────┬──────────┘
          │                             │
          ├─────────────┬───────────────┤
          │             │               │
┌─────────▼─────┐  ┌────▼────┐  ┌──────▼────────┐
│ Ollama Local  │  │ HF Cloud│  │ Qdrant Vector │
│ (llama3:8b)   │  │ Fallback│  │  10.101.86.126│
│               │  │         │  │               │
│ RTX 3080 +    │  │ API Key │  │ - Embeddings  │
│ RTX 2060 Super│  │ Secured │  │ - RAG Support │
└───────────────┘  └─────────┘  └───────────────┘
```

---

## 🔐 Security Notes

- All secrets stored in Kubernetes secrets
- HuggingFace tokens are redacted in logs
- TLS certificates managed by cert-manager (self-signed)
- No external exposure without explicit ingress configuration

---

## 📚 Additional Resources

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Llama 3 Model Card](https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [vLLM Documentation](https://docs.vllm.ai/)

---

**Maintained by:** daclab-ai  
**Infrastructure:** Kubernetes on-premises cluster  
**GPU Resources:** 2x NVIDIA GPUs (RTX 3080 12GB + RTX 2060 Super 8GB)
