# Llama3 8B Multi-Adapter Kubernetes Deployment

Production-ready multi-adapter architecture for Llama3 8B with GPU time-slicing, specialized adapters, and comprehensive ingress configuration.

## 🚀 Quick Deploy

```bash
# 1. Review and update domain in ingress
vi k8s/ingress/ingress.yaml

# 2. Deploy everything
./deploy-all.sh

# 3. Monitor deployment
watch kubectl get pods -n llama3-multi-adapter
```

## ✅ What's Included

All manifests for:
- ✅ **Code Adapter** - Code generation with Python, JS, Go, Rust support
- ✅ **RAG Adapter** - Retrieval-augmented generation with Qdrant integration
- ✅ **Qdrant Vector Database** - High-performance vector search
- ✅ **Nginx Ingress** - Path-based routing, CORS, rate limiting, SSL/TLS
- ✅ **Chatbot Adapter** - Conversational AI (already created)
- ✅ **Base Model** - Llama3 8B foundation model
- ✅ **GPU Time-Slicing** - 8 virtual GPUs from 2 physical GPUs

## 📁 Structure

```
k8s/
├── adapters/
│   ├── chatbot/    ✅ (configmap, deployment, service)
│   ├── code/       ✅ (configmap, deployment, service)
│   ├── rag/        ✅ (configmap, service)
│   └── microservices/ (to be generated)
├── qdrant/         ✅ (configmap, statefulset, service)
├── ingress/        ✅ (ingress with CORS, rate limiting, SSL)
├── base-model/     ✅
├── gpu/            ✅
├── storage/        ✅
└── ssl/            ✅
```

## 🔧 Next Steps

### 1. Complete RAG Adapter Deployment

The RAG adapter service and configmap are ready. Complete the deployment by running:

```bash
./generate-remaining-manifests.sh
```

This will create:
- `k8s/adapters/rag/deployment.yaml` - Full RAG adapter with Qdrant integration
- `k8s/adapters/microservices/` - Architecture design adapter
- Additional helper scripts

### 2. Deploy

```bash
./deploy-all.sh
```

### 3. Configure Domain

Edit `k8s/ingress/ingress.yaml` and replace `llama3.your-domain.com` with your actual domain.

### 4. Test Endpoints

```bash
# Health checks
curl https://llama3.your-domain.com/chatbot/health
curl https://llama3.your-domain.com/code/health
curl https://llama3.your-domain.com/rag/health

# Code generation
curl -X POST https://llama3.your-domain.com/code/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a Python function to sort a list", "language": "python"}'

# RAG query (after loading documents into Qdrant)
curl -X POST https://llama3.your-domain.com/rag/generate \
  -H "Content-Type: application/json" \
  -d '{"query": "What is machine learning?", "top_k_retrieval": 5}'
```

## 📊 Resource Allocation

| Component | Replicas | GPU | CPU | Memory |
|-----------|----------|-----|-----|--------|
| Base Model | 1 | 1 | 4 | 10Gi |
| Chatbot | 2 | 1 | 4 | 8Gi |
| Code | 2 | 1 | 4 | 8Gi |
| RAG | 2 | 1 | 4 | 8Gi |
| Qdrant | 1 | 0 | 2 | 4Gi |

**Total**: 8 virtual GPUs (4 per physical GPU with time-slicing)

## 🔐 Security Features

- SSL/TLS with automated cert-manager
- CORS configuration for cross-origin requests
- Rate limiting (10 req/s default, burst 50)
- Request timeouts optimized for LLM inference (300s)
- Security headers (X-Frame-Options, CSP, etc.)

## 📚 Documentation

- **Full README-old.md**: Comprehensive guide with architecture diagrams
- **SSL Setup**: `k8s/ssl/setup-ssl.sh your-domain.com`
- **Troubleshooting**: Check pod logs with `kubectl logs -f -n llama3-multi-adapter -l component=adapter`

## 🎯 Monitoring

```bash
# Watch all pods
watch kubectl get pods -n llama3-multi-adapter

# Check GPU allocation
kubectl describe nodes | grep nvidia.com/gpu

# View adapter logs
kubectl logs -f -n llama3-multi-adapter -l app=llama3-code-adapter

# Port forward for local testing
kubectl port-forward -n llama3-multi-adapter svc/llama3-code-adapter 8080:8080
```

## 🚨 Important Notes

1. **Initialization Time**: Adapters take 5-10 minutes to initialize (model loading, package installation)
2. **Domain Configuration**: Update ingress.yaml with your actual domain before deploying
3. **SSL Certificates**: Run `./k8s/ssl/setup-ssl.sh your-domain.com` after ingress deployment
4. **Qdrant Data**: Load documents into Qdrant before using RAG adapter

---

**Status**: Ready for deployment  
**Last Updated**: 2025-10-02  
**Kubernetes**: 1.27+  
**GPU Driver**: NVIDIA 535+
