# Multi-Adapter LLM System - Complete Redesign

## Hardware Resources
- **GPUs**: 2x NVIDIA (20GB VRAM total - ~10GB each)
- **CPU**: 64 cores (32 physical cores, 64 threads)
- **RAM**: 128GB
- **Strategy**: Use GPU time-slicing for multiple pods per GPU

## Required Adapters (Microservice Architecture)

### 1. Chatbot Adapter
- **Purpose**: Conversational AI, general Q&A
- **Model**: Llama3 8B base or fine-tuned chat variant
- **Replicas**: 2 (one per GPU for HA)
- **Resources**: 0.5 GPU, 4 CPU, 8GB RAM per replica

### 2. RAG + Vector Search Adapter
- **Purpose**: Retrieval-Augmented Generation with semantic search
- **Components**: 
  - Llama3 8B for generation
  - Embedding model for vector search
  - Qdrant vector DB integration
- **Replicas**: 2
- **Resources**: 0.5 GPU, 6 CPU, 12GB RAM per replica

### 3. Code Writer Adapter
- **Purpose**: Code generation, completion, refactoring
- **Model**: Llama3 8B code-tuned or CodeLlama
- **Replicas**: 2
- **Resources**: 0.5 GPU, 4 CPU, 8GB RAM per replica

### 4. Microservices Adapter
- **Purpose**: API design, microservice architecture generation
- **Model**: Llama3 8B with system design context
- **Replicas**: 1
- **Resources**: 0.5 GPU, 2 CPU, 6GB RAM

## Proxy & Routing Layer

### Nginx Ingress with:
- **HTTPS/TLS**: Let's Encrypt via cert-manager
- **HTTP → HTTPS redirect**
- **CORS headers**: Allow cross-origin requests
- **Rate limiting**: Per-client limits
- **Path-based routing**:
  - `/chat` → Chatbot adapter
  - `/rag` → RAG adapter
  - `/code` → Code writer
  - `/microservices` → Microservices adapter
  - `/vector-search` → RAG vector search endpoint

## Storage Architecture
- **Base models**: 50GB RWX (shared across all)
- **Per-adapter storage**: 10GB RWO each
- **Vector DB**: 20GB RWO for Qdrant

## Implementation Steps
1. Enable GPU time-slicing (allow 4 pods per GPU)
2. Deploy base infrastructure (storage, namespace)
3. Deploy adapters with correct resource requests
4. Deploy Nginx proxy with CORS and SSL
5. Configure routing and health checks
6. Test each endpoint

## GPU Time-Slicing Configuration
Configure NVIDIA device plugin to allow 4 replicas per GPU:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: device-plugin-config
  namespace: kube-system
data:
  config.yaml: |
    version: v1
    sharing:
      timeSlicing:
        replicas: 4
```

This allows: 2 GPUs × 4 pods = 8 concurrent pods total
