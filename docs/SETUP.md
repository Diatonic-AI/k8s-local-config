# Environment Setup Guide

This guide walks through bringing up the Diatonic AI Llama 3 multi-adapter stack on a fresh Kubernetes cluster.

## Prerequisites
- Kubernetes cluster v1.27 or newer with GPU worker nodes
- `kubectl` configured with cluster admin permissions
- StorageClass capable of provisioning RWX or RWO volumes sized ≥ 200Gi
- `helm` (optional) for installing dependencies such as cert-manager
- CLI tooling: `yamllint`, `kubeconform`, `jq`

## 1. Validate Repository
```bash
git clone git@github.com:diatonic-ai/k8s-local-config.git
cd k8s-local-config
yamllint -c .yamllint.yaml .
find k8s-manifests -name "*.yaml" | xargs kubeconform -summary
```

## 2. Prepare Cluster
1. **Install NVIDIA drivers** on GPU nodes and enable `nvidia-container-toolkit`.
2. **Install cert-manager** (if not already present):
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm upgrade --install cert-manager jetstack/cert-manager \
     --namespace cert-manager --create-namespace \
     --set installCRDs=true
   ```
3. Ensure a default `StorageClass` exists and is marked as default (`storageclass.kubernetes.io/is-default-class=true`).

## 3. Configure GPU Time Slicing
```bash
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/00-gpu-time-slicing/time-slicing-config.yaml
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/00-gpu-time-slicing/nvidia-device-plugin-with-timeslicing.yaml
```
Verify pods:
```bash
kubectl get pods -n gpu-operators
```

## 4. Bootstrap Certificates
```bash
kubectl apply -f k8s-manifests/certificate-manager/cluster-issuer-selfsigned.yaml
kubectl apply -f k8s-manifests/certificate-manager/llama3-certificate.yaml
```
For production, replace with ACME/Let’s Encrypt issuers before promoting traffic.

## 5. Deploy Core Namespace and Storage
```bash
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/01-namespace/
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/02-storage/
```
Confirm PVCs bind successfully before continuing:
```bash
kubectl get pvc -n llama3-multi-adapter
```

## 6. Launch Base Model and Adapters
```bash
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/03-base-model/
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/04-adapters/
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/k8s/
```
The helper script `deploy-all.sh` orchestrates the same sequence with readiness checks.

## 7. Validate Deployment
```bash
kubectl get pods -n llama3-multi-adapter
kubectl get svc -n llama3-multi-adapter
kubectl logs -n llama3-multi-adapter deploy/llama3-base-model
```
Run adapter smoke tests:
```bash
./k8s-manifests/llama3-8b-deployment/multi-adapter/test-and-load-models.sh
```

## 8. Expose Endpoints
```bash
kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/ssl/
```
Update hostnames/annotations to match the target ingress controller and DNS records.

## 9. Teardown (Optional)
```bash
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/ssl/
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/k8s/
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/04-adapters/
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/03-base-model/
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/02-storage/
kubectl delete -f k8s-manifests/llama3-8b-deployment/multi-adapter/01-namespace/
```
Remove GPU components only after workloads stop.

## Next Steps
- Integrate with GitOps (Flux/Argo CD) for continuous delivery.
- Enable monitoring via Prometheus/Grafana scraping the adapter metrics endpoints.
- Configure external DNS and certificates before routing production traffic.
