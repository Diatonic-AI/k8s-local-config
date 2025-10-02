#!/bin/bash
set -euo pipefail

echo "🎮 Setting up GPU Time-Slicing for K3s"
echo "======================================"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
   echo "⚠️  This script needs sudo privileges. Rerun with sudo."
   exit 1
fi

echo ""
echo "📋 Step 1: Checking for existing NVIDIA device plugin..."
if kubectl get daemonset -n kube-system | grep -q nvidia-device-plugin; then
    echo "⚠️  Found existing NVIDIA device plugin. Deleting..."
    kubectl delete daemonset nvidia-device-plugin-daemonset -n kube-system --ignore-not-found=true
    echo "✅ Deleted existing device plugin"
    sleep 3
fi

echo ""
echo "📋 Step 2: Applying GPU time-slicing configuration..."
kubectl apply -f time-slicing-config.yaml
echo "✅ ConfigMap created"

echo ""
echo "📋 Step 3: Deploying NVIDIA device plugin with time-slicing..."
kubectl apply -f nvidia-device-plugin-with-timeslicing.yaml
echo "✅ Device plugin deployed"

echo ""
echo "📋 Step 4: Waiting for device plugin to be ready..."
echo "    (This may take 30-60 seconds...)"
sleep 5

# Wait for daemonset to be ready
kubectl rollout status daemonset/nvidia-device-plugin-daemonset -n kube-system --timeout=120s

echo ""
echo "📋 Step 5: Verifying GPU time-slicing configuration..."
sleep 3

# Check GPU capacity
echo ""
echo "GPU Capacity per Node:"
kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | "\(.metadata.name): \(.status.capacity."nvidia.com/gpu") GPUs (with time-slicing: \(.status.capacity."nvidia.com/gpu" | tonumber * 4) virtual GPUs)"'

echo ""
echo "✅ GPU Time-Slicing Setup Complete!"
echo ""
echo "📊 Summary:"
echo "   - Physical GPUs: 2"
echo "   - Virtual GPUs (time-sliced): 8"
echo "   - Replicas per GPU: 4"
echo ""
echo "🎯 Next Steps:"
echo "   1. Deploy namespace: kubectl apply -f ../01-namespace/"
echo "   2. Deploy storage: kubectl apply -f ../02-storage/"
echo "   3. Deploy base model: kubectl apply -f ../03-base-model/"
echo ""
