# Kubernetes Manifest Analysis

## Summary Metrics
- Total YAML manifests: 65
- Primary directories analyzed: `k8s-manifests/certificate-manager`, `k8s-manifests/llama3-8b-deployment`

## Directory Structure (depth ≤ 3)
```
k8s-manifests
├── certificate-manager
│   ├── cluster-issuer-selfsigned.yaml
│   ├── deploy-all.sh
│   ├── install-cert-manager.sh
│   ├── llama3-certificate.yaml
│   └── README.md
└── llama3-8b-deployment
    ├── multi-adapter
    │   ├── 00-gpu-time-slicing
    │   ├── 01-namespace
    │   ├── 02-storage
    │   ├── 03-base-model
    │   ├── 04-adapters
    │   ├── adapters
    │   ├── ARCHITECTURE.md
    │   ├── base
    │   ├── deploy-all.sh
    │   ├── DEPLOYMENT-COMPLETED.md
    │   ├── DEPLOYMENT-SUMMARY.md
    │   ├── generate-remaining-manifests-broken.sh
    │   ├── generate-remaining-manifests.sh
    │   ├── GPU-ALLOCATION-FIXED.md
    │   ├── IMPLEMENTATION-GUIDE.md
    │   ├── k8s
    │   ├── namespace.yaml
    │   ├── QUICK-START.md
    │   ├── README.md
    │   ├── README-old.md
    │   ├── REDESIGN-PLAN.md
    │   ├── routing
    │   ├── scripts
    │   ├── simple-fast-deployment.yaml
    │   ├── ssl
    │   ├── storage
    │   ├── test-and-load-models.sh
    │   ├── vllm-deployment.yaml
    │   └── YAML-FIXES-COMPLETED.md
    └── PERFORMANCE_OPTIMIZATION.md
```

## Resource Type Distribution
```
21  PersistentVolumeClaim
18  Service
16  Deployment
10  ConfigMap
 9  ClusterIssuer
 6  Ingress
 4  DaemonSet
 3  Namespace
 3  Certificate
 1  StatefulSet
```

## Key Components Identified
- GPU partitioning stack in `00-gpu-time-slicing/` using the NVIDIA device plugin and a `time-slicing-config` ConfigMap.
- Certificate management automation under `certificate-manager/` with `ClusterIssuer` definitions and helper scripts for cert-manager bootstrap.
- Core Llama 3 8B vLLM deployment in `03-base-model/` paired with services and persistent storage requirements.
- Multi-adapter architecture (`04-adapters/`, `k8s/adapters/`) covering RAG, router, and streaming adapters backed by ConfigMaps and Deployments.
- Qdrant vector database StatefulSet plus Services in `k8s/qdrant/` with dedicated PVCs defined in `02-storage/`.
- Ingress and TLS assets in `ssl/` coordinating with issued certificates to expose the model endpoints securely.
