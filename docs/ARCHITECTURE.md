# Platform Architecture

## Overview
The `k8s-local-config` repository codifies the Kubernetes footprint for Diatonic AI's Llama 3 platforms. The manifests cater to local development clusters, on-prem GPU nodes, and production-grade environments. The stack centers on a vLLM-based serving layer complemented by adapter services, GPU resource partitioning, secure ingress, and vector-search infrastructure.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Diatonic AI Kubernetes                             │
├──────────────────────────────────────────────────────────────────────────────┤
│ GPU Node Pool                                                                 │
│  ├─ NVIDIA Device Plugin (time slicing)                                       │
│  └─ vLLM Deployments + Adapter Pods                                           │
│                                                                              │
│ Control Plane                                                                 │
│  ├─ Namespace + RBAC                                                          │
│  ├─ ConfigMaps / Secrets                                                      │
│  ├─ Cert-Manager ClusterIssuers                                               │
│                                                                              │
│ Data Plane                                                                    │
│  ├─ Qdrant StatefulSet + PVCs                                                 │
│  ├─ Persistent Volumes for models and adapters                                │
│                                                                              │
│ Edge                                                                          │
│  ├─ NGINX/Contour Ingress                                                     │
│  └─ TLS Certificates                                                          │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Workload Layout
- **Namespace (`llama3-multi-adapter`)** creates a security boundary for LLM-serving components.
- **Deployments** deliver the vLLM base model (`03-base-model/`) and adapter workloads (`04-adapters/`, `k8s/adapters/`). Each pod mounts persistent model volumes and exposes HTTP/gRPC endpoints internally.
- **StatefulSet** for Qdrant (`k8s/qdrant/`) ensures durable vector storage with dedicated PVCs for collections and snapshots.
- **DaemonSets** under `00-gpu-time-slicing/` configure NVIDIA GPU partitioning on every GPU node, enabling fractional GPU slices per adapter.

## Storage Strategy
- PersistentVolumeClaims live in `02-storage/` and `storage/` folders, allocating block volumes for:
  - Llama 3 base model artifacts
  - Adapter-specific embeddings or cache directories
  - Qdrant data (`qdrant-storage`) and snapshots
- Storage classes are expected to be provided by the cluster (e.g., `longhorn`, `rook-ceph`, `local-path`). Update PVC sizes to match the target cluster's capacity planning.

## Networking and Routing
- Services expose each microservice internally. A combination of `ClusterIP` and headless Services is used for Qdrant.
- Ingress resources within `ssl/` terminate TLS by referencing certificates provisioned by cert-manager (`certificate-manager/`). Hostname defaults can be patched per environment via overlays or Kustomize.
- For local clusters (k3s/kind/microk8s), scripts in `scripts/` and `deploy-all.sh` automate sequential application of manifests.

## Security Controls
- cert-manager integration yields ACME or self-signed certificates (see `cluster-issuer-selfsigned.yaml` and `llama3-certificate.yaml`).
- Adapters receive per-service ConfigMaps to inject vector DB credentials and routing metadata.
- RBAC manifests (when present) should be tailored by environment; defaults assume cluster admin control for bootstrap.
- NetworkPolicy resources are not yet defined—consider adding them before production launch.

## GPU Scheduling Model
- `nvidia-device-plugin-with-timeslicing.yaml` deploys NVIDIA's device plugin configured for MIG/time-slicing.
- `time-slicing-config.yaml` declares slice profiles (e.g., `1g.10gb`) which the device plugin consumes to expose virtual GPUs.
- Adapter and base model Deployments request fractional GPUs by setting `nvidia.com/gpu` resource limits equal to the slice count.

## Observability Hooks
- Standard metrics endpoints are exposed via HTTP, ready for integration with Prometheus operators.
- Logs are directed to stdout/stderr for ingestion by cluster-level logging stacks (e.g., Fluent Bit).
- Health endpoints (`/healthz`, `/readyz`) are wired into `readinessProbe` and `livenessProbe` fields across Deployments.

## Environment Promotion
1. **Local development** (kind, k3d, minikube): apply manifests selectively and leverage self-signed issuers.
2. **Staging**: integrate with staging DNS zones, adjust replica counts, and enable external TLS certificates.
3. **Production**: scale replicas, configure horizontal pod autoscalers (not yet included), and harden storage/network policies.

## Extensibility
- Adapter manifests are modular; new adapters can be added under `k8s/adapters/<name>/` with associated ConfigMaps and Service definitions.
- Overlays can be introduced using Kustomize by replicating directories under `overlays/` (not yet present).
- Scripts under `multi-adapter/scripts/` aid in a full-cluster rollout; extend them to perform validation gates or integrate with GitOps pipelines.
