#!/bin/bash

NAMESPACE="llama3-multi-adapter"

echo "📊 Multi-Adapter Resource Monitoring"
echo "====================================="
echo ""

while true; do
  clear
  echo "📊 Multi-Adapter Resource Monitoring - $(date)"
  echo "=============================================="
  echo ""
  
  echo "🎯 Pod Status:"
  kubectl get pods -n $NAMESPACE -o wide
  echo ""
  
  echo "💾 Storage Usage:"
  kubectl get pvc -n $NAMESPACE
  echo ""
  
  echo "🔥 GPU Usage (from pod labels):"
  echo "GPU 0 Pods (Base + Chatbot):"
  kubectl get pods -n $NAMESPACE -l gpu-id=0 --no-headers | wc -l
  echo "GPU 1 Pods (Code + Summarization):"
  kubectl get pods -n $NAMESPACE -l gpu-id=1 --no-headers | wc -l
  echo ""
  
  echo "📈 Resource Requests vs Limits:"
  kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"
  echo ""
  
  echo "🔄 Recent Events:"
  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
  echo ""
  
  echo "Press Ctrl+C to exit..."
  sleep 10
done
