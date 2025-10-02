# Multi-Adapter Llama3 8B Deployment

## Overview

This deployment architecture enables **parallel execution of multiple task-specific adapters** on a single Llama3 8B base model, maximizing resource utilization on local hardware with 2 GPUs, 16 CPU cores, and 64GB RAM.

## Architecture

### Hardware Allocation

| Component | GPU | VRAM | CPU | RAM | Replicas |
|-----------|-----|------|-----|-----|----------|
| **Base Model** | GPU 0 | 8GB | 2 cores | 8GB | 1 |
| **Chatbot Adapter** | GPU 0 | 4GB each | 2 cores each | 8GB each | 3 |
| **Code Adapter** | GPU 1 | 6GB each | 2 cores each | 8GB each | 2 |
| **Summarization Adapter** | GPU 1 | 8GB | 2 cores | 8GB | 1 |
| **Total** | Both | 40GB | 14 cores | 56GB | 7 pods |
| **System Reserve** | - | - | 2 cores | 8GB | - |

### GPU Distribution

**GPU 0 (20GB VRAM):**
- Base Model: 8GB
- 3x Chatbot replicas: 12GB (4GB each)
- Total: 20GB

**GPU 1 (20GB VRAM):**
- 2x Code replicas: 12GB (6GB each)
- 1x Summarization: 8GB
- Total: 20GB

## Directory Structure

```
multi-adapter/
├── ARCHITECTURE.md              # Detailed architecture documentation
├── README.md                    # This file
├── namespace.yaml               # llama3-multi-adapter namespace
├── storage/
│   ├── base-models-pvc.yaml    # Shared base model storage (50GB)
│   ├── chatbot-adapter-pvc.yaml
│   ├── code-adapter-pvc.yaml
│   └── summarization-adapter-pvc.yaml
├── base/
│   ├── deployment.yaml          # Base Ollama (GPU 0, 1 replica)
│   └── service.yaml
├── adapters/
│   ├── chatbot/
│   │   ├── deployment.yaml     # 3 replicas on GPU 0
│   │   └── service.yaml
│   ├── code/
│   │   ├── deployment.yaml     # 2 replicas on GPU 1
│   │   └── service.yaml
│   └── summarization/
│       ├── deployment.yaml      # 1 replica on GPU 1
│       └── service.yaml
├── routing/
│   └── ingress.yaml             # Path-based routing
└── scripts/
    ├── deploy-all.sh            # Automated deployment
    ├── test-adapters.sh         # Endpoint testing
    ├── monitor.sh               # Resource monitoring
    └── rollback.sh              # Rollback to previous deployment
```

## Deployment Guide

### Prerequisites

1. **Kubernetes Cluster**: k3s with NVIDIA GPU support
2. **GPU Operator**: NVIDIA device plugin installed
3. **Storage Class**: `local-path` (or modify storage YAMLs)
4. **Ingress Controller**: Nginx (optional, for path-based routing)

### Quick Start

```bash
# 1. Deploy everything
cd /home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter
./scripts/deploy-all.sh

# 2. Load base model (in base pod)
kubectl exec -n llama3-multi-adapter -it deployment/ollama-base -- ollama pull llama3:8b

# 3. (Optional) Load adapter models
# For chatbot adapter
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-chatbot -- ollama pull <chatbot-adapter-model>

# For code adapter
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-code -- ollama pull <code-adapter-model>

# For summarization adapter
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-summarization -- ollama pull <summarization-adapter-model>

# 4. Test endpoints
./scripts/test-adapters.sh

# 5. Monitor resources
./scripts/monitor.sh
```

### Manual Deployment (Step-by-Step)

```bash
# Phase 1: Namespace
kubectl apply -f namespace.yaml

# Phase 2: Storage
kubectl apply -f storage/

# Phase 3: Base Model
kubectl apply -f base/

# Phase 4: Adapters
kubectl apply -f adapters/chatbot/
kubectl apply -f adapters/code/
kubectl apply -f adapters/summarization/

# Phase 5: Routing
kubectl apply -f routing/
```

## Service Endpoints

### Internal Cluster Access

```bash
# Base model (no adapter)
curl -X POST http://ollama-base.llama3-multi-adapter:11434/api/generate \
  -d '{"model":"llama3:8b","prompt":"Hello"}'

# Chatbot adapter
curl -X POST http://ollama-chatbot.llama3-multi-adapter:11434/api/generate \
  -d '{"model":"<adapter-model>","prompt":"Chat with me"}'

# Code adapter
curl -X POST http://ollama-code.llama3-multi-adapter:11434/api/generate \
  -d '{"model":"<adapter-model>","prompt":"Write a function to..."}'

# Summarization adapter
curl -X POST http://ollama-summarization.llama3-multi-adapter:11434/api/generate \
  -d '{"model":"<adapter-model>","prompt":"Summarize this: ..."}'
```

### Ingress Access (if configured)

Add to `/etc/hosts`:
```
<node-ip> ollama.local
```

Then access via:
```bash
# Base
curl http://ollama.local/base/api/tags

# Chatbot
curl http://ollama.local/chatbot/api/tags

# Code
curl http://ollama.local/code/api/tags

# Summarization
curl http://ollama.local/summarization/api/tags
```

## Resource Management

### Scaling Adapters

```bash
# Scale chatbot adapter (high traffic)
kubectl scale deployment ollama-adapter-chatbot -n llama3-multi-adapter --replicas=5

# Scale code adapter (moderate traffic)
kubectl scale deployment ollama-adapter-code -n llama3-multi-adapter --replicas=3

# Scale down summarization (low traffic)
kubectl scale deployment ollama-adapter-summarization -n llama3-multi-adapter --replicas=0
```

### GPU Memory Management

Each adapter has `OLLAMA_GPU_MEMORY_FRACTION` set:
- **Chatbot**: 0.2 (~4GB per replica)
- **Code**: 0.3 (~6GB per replica)
- **Summarization**: 0.4 (~8GB)

Adjust in deployment YAMLs if needed.

### CPU and RAM Limits

All pods have:
- **Requests**: 2 cores, 8GB RAM
- **Limits**: 3-4 cores, 10-12GB RAM

Kubernetes will pack pods efficiently within the 16-core/64GB constraints.

## Monitoring

### Watch Pod Status

```bash
watch kubectl get pods -n llama3-multi-adapter -o wide
```

### GPU Utilization

```bash
# On the node (direct nvidia-smi)
nvidia-smi

# Or use DCGM exporter (if installed)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes/<node-name> | jq
```

### Logs

```bash
# Base model logs
kubectl logs -n llama3-multi-adapter deployment/ollama-base -f

# Chatbot adapter logs
kubectl logs -n llama3-multi-adapter deployment/ollama-adapter-chatbot -f

# All adapter logs
kubectl logs -n llama3-multi-adapter -l app.kubernetes.io/component=adapter -f --max-log-requests=10
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check resource availability
kubectl describe pod -n llama3-multi-adapter <pod-name>

# Common issues:
# - GPU not available: Check nvidia device plugin
# - PVC not bound: Check storage class and volume availability
# - Resource limits: Increase node resources or scale down replicas
```

### Adapter Not Loading Model

```bash
# Check adapter storage
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-<type> -- ls -la /adapters/.ollama/adapters

# Pull model manually
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-<type> -- ollama pull <model-name>
```

### High Latency / OOM Errors

```bash
# Check GPU memory usage
kubectl exec -n llama3-multi-adapter -it deployment/ollama-adapter-<type> -- nvidia-smi

# Reduce replicas or adjust OLLAMA_GPU_MEMORY_FRACTION
kubectl edit deployment ollama-adapter-<type> -n llama3-multi-adapter
```

## Rollback

To rollback to the previous single deployment:

```bash
./scripts/rollback.sh

# Then restore old deployment
kubectl apply -f ../ollama/ollama-deployment-final.yaml
kubectl apply -f ../ollama/ollama-service.yaml
```

## Advanced Configuration

### Enable Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ollama-adapter-chatbot-hpa
  namespace: llama3-multi-adapter
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ollama-adapter-chatbot
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Add Custom Adapter

1. **Create PVC**:
   ```yaml
   # storage/custom-adapter-pvc.yaml
   ```

2. **Create Deployment**:
   ```yaml
   # adapters/custom/deployment.yaml
   ```

3. **Create Service**:
   ```yaml
   # adapters/custom/service.yaml
   ```

4. **Update Ingress**:
   ```yaml
   # routing/ingress.yaml
   - path: /custom(/|$)(.*)
     pathType: ImplementationSpecific
     backend:
       service:
         name: ollama-custom
         port:
           number: 11434
   ```

## Performance Tuning

### Concurrency Settings

| Adapter | OLLAMA_NUM_PARALLEL | OLLAMA_MAX_QUEUE | Rationale |
|---------|---------------------|------------------|-----------|
| Base | 2 | 128 | Low load, fallback only |
| Chatbot | 4 | 256 | High concurrency |
| Code | 3 | 128 | Moderate concurrency |
| Summarization | 2 | 64 | Batch processing |

### Keep-Alive Times

- **Base**: 24h (always ready)
- **Chatbot**: 10m (frequent access)
- **Code**: 15m (moderate access)
- **Summarization**: 20m (batch jobs)

## Best Practices

1. **Always Load Base Model First**: Adapters depend on the base model being available.

2. **Monitor GPU Memory**: Use `nvidia-smi` to track VRAM usage per GPU.

3. **Scale Gradually**: Start with default replicas, then scale based on actual traffic.

4. **Use Session Affinity**: Services have `sessionAffinity: ClientIP` for better caching.

5. **Separate Logs**: Keep adapter logs separate for easier debugging.

6. **Test Before Production**: Use `test-adapters.sh` to verify all endpoints work.

## Migration from Single Deployment

If you have the existing `ollama-llama3` deployment running:

```bash
# 1. Backup current deployment
kubectl get deployment ollama-llama3 -n llama3 -o yaml > ollama-llama3-backup.yaml

# 2. Scale down old deployment (optional, for testing)
kubectl scale deployment ollama-llama3 -n llama3 --replicas=0

# 3. Deploy multi-adapter
cd multi-adapter
./scripts/deploy-all.sh

# 4. Test multi-adapter
./scripts/test-adapters.sh

# 5. If successful, delete old deployment
kubectl delete -f ../ollama/

# 6. If issues, rollback
./scripts/rollback.sh
kubectl scale deployment ollama-llama3 -n llama3 --replicas=1
```

## Support & Maintenance

- **Documentation**: See `ARCHITECTURE.md` for detailed design decisions
- **Issues**: Check pod logs and events for error messages
- **Updates**: Pull latest Ollama image and restart deployments

## License

Same as parent project.
