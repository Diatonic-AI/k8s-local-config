#!/bin/bash
set -euo pipefail

BASE_DIR="/home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter"

echo "🚀 Generating remaining multi-adapter manifests..."

# Code Adapter Deployment (GPU 1, 2 replicas)
cat > "$BASE_DIR/adapters/code/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-adapter-code
  namespace: llama3-multi-adapter
  labels:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: code-adapter
    app.kubernetes.io/component: adapter
    app.kubernetes.io/adapter-type: code
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: ollama
      app.kubernetes.io/instance: code-adapter
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ollama
        app.kubernetes.io/instance: code-adapter
        app.kubernetes.io/component: adapter
        app.kubernetes.io/adapter-type: code
        gpu-id: "1"
    spec:
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: setup-permissions
        image: busybox:1.36
        command: ['sh', '-c']
        args:
        - |
          mkdir -p /adapters/.ollama/adapters
          chown -R 1001:1001 /adapters
          chmod -R 755 /adapters
        volumeMounts:
        - name: adapter-storage
          mountPath: /adapters
        securityContext:
          runAsUser: 0
      containers:
      - name: ollama
        image: ollama/ollama:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 11434
          name: http
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: HOME
          value: "/adapters"
        - name: OLLAMA_MODELS
          value: "/models/.ollama/models:/adapters/.ollama/adapters"
        - name: OLLAMA_ADAPTER_TYPE
          value: "code"
        - name: OLLAMA_KEEP_ALIVE
          value: "15m"
        - name: OLLAMA_MAX_LOADED_MODELS
          value: "1"
        - name: NVIDIA_VISIBLE_DEVICES
          value: "1"
        - name: NVIDIA_DRIVER_CAPABILITIES
          value: "compute,utility"
        - name: CUDA_VISIBLE_DEVICES
          value: "1"
        - name: OLLAMA_GPU_DRIVER
          value: "cuda"
        - name: OLLAMA_NUM_PARALLEL
          value: "3"
        - name: OLLAMA_MAX_QUEUE
          value: "128"
        - name: OLLAMA_GPU_MEMORY_FRACTION
          value: "0.3"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1001
          runAsGroup: 1001
          capabilities:
            drop: [ALL]
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - name: base-models
          mountPath: /models
          readOnly: true
        - name: adapter-storage
          mountPath: /adapters
        resources:
          requests:
            cpu: "2000m"
            memory: "8Gi"
            nvidia.com/gpu: 1
          limits:
            cpu: "4000m"
            memory: "12Gi"
            nvidia.com/gpu: 1
        livenessProbe:
          httpGet:
            path: /api/tags
            port: http
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/tags
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: base-models
        persistentVolumeClaim:
          claimName: llama3-base-models-pvc
      - name: adapter-storage
        persistentVolumeClaim:
          claimName: llama3-code-adapter-pvc
      nodeSelector:
        nvidia.com/gpu.present: "true"
      runtimeClassName: nvidia
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/instance
                  operator: In
                  values: [code-adapter]
              topologyKey: kubernetes.io/hostname
EOF

cat > "$BASE_DIR/adapters/code/service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ollama-code
  namespace: llama3-multi-adapter
  labels:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: code-adapter
    app.kubernetes.io/component: adapter
    app.kubernetes.io/adapter-type: code
spec:
  type: ClusterIP
  ports:
  - port: 11434
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: code-adapter
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
EOF

# Summarization Adapter Deployment (GPU 1, 1 replica)
cat > "$BASE_DIR/adapters/summarization/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-adapter-summarization
  namespace: llama3-multi-adapter
  labels:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: summarization-adapter
    app.kubernetes.io/component: adapter
    app.kubernetes.io/adapter-type: summarization
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: ollama
      app.kubernetes.io/instance: summarization-adapter
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ollama
        app.kubernetes.io/instance: summarization-adapter
        app.kubernetes.io/component: adapter
        app.kubernetes.io/adapter-type: summarization
        gpu-id: "1"
    spec:
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: setup-permissions
        image: busybox:1.36
        command: ['sh', '-c']
        args:
        - |
          mkdir -p /adapters/.ollama/adapters
          chown -R 1001:1001 /adapters
          chmod -R 755 /adapters
        volumeMounts:
        - name: adapter-storage
          mountPath: /adapters
        securityContext:
          runAsUser: 0
      containers:
      - name: ollama
        image: ollama/ollama:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 11434
          name: http
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: HOME
          value: "/adapters"
        - name: OLLAMA_MODELS
          value: "/models/.ollama/models:/adapters/.ollama/adapters"
        - name: OLLAMA_ADAPTER_TYPE
          value: "summarization"
        - name: OLLAMA_KEEP_ALIVE
          value: "20m"
        - name: OLLAMA_MAX_LOADED_MODELS
          value: "1"
        - name: NVIDIA_VISIBLE_DEVICES
          value: "1"
        - name: NVIDIA_DRIVER_CAPABILITIES
          value: "compute,utility"
        - name: CUDA_VISIBLE_DEVICES
          value: "1"
        - name: OLLAMA_GPU_DRIVER
          value: "cuda"
        - name: OLLAMA_NUM_PARALLEL
          value: "2"
        - name: OLLAMA_MAX_QUEUE
          value: "64"
        - name: OLLAMA_GPU_MEMORY_FRACTION
          value: "0.4"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1001
          runAsGroup: 1001
          capabilities:
            drop: [ALL]
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - name: base-models
          mountPath: /models
          readOnly: true
        - name: adapter-storage
          mountPath: /adapters
        resources:
          requests:
            cpu: "2000m"
            memory: "8Gi"
            nvidia.com/gpu: 1
          limits:
            cpu: "4000m"
            memory: "12Gi"
            nvidia.com/gpu: 1
        livenessProbe:
          httpGet:
            path: /api/tags
            port: http
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/tags
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: base-models
        persistentVolumeClaim:
          claimName: llama3-base-models-pvc
      - name: adapter-storage
        persistentVolumeClaim:
          claimName: llama3-summarization-adapter-pvc
      nodeSelector:
        nvidia.com/gpu.present: "true"
      runtimeClassName: nvidia
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
EOF

cat > "$BASE_DIR/adapters/summarization/service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ollama-summarization
  namespace: llama3-multi-adapter
  labels:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: summarization-adapter
    app.kubernetes.io/component: adapter
    app.kubernetes.io/adapter-type: summarization
spec:
  type: ClusterIP
  ports:
  - port: 11434
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: ollama
    app.kubernetes.io/instance: summarization-adapter
EOF

# Ingress for routing
cat > "$BASE_DIR/routing/ingress.yaml" << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama-multi-adapter
  namespace: llama3-multi-adapter
  labels:
    app.kubernetes.io/part-of: ai-inference
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
spec:
  ingressClassName: nginx
  rules:
  - host: ollama.local
    http:
      paths:
      # Base model (no adapter)
      - path: /base(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: ollama-base
            port:
              number: 11434
      # Chatbot adapter
      - path: /chatbot(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: ollama-chatbot
            port:
              number: 11434
      # Code adapter
      - path: /code(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: ollama-code
            port:
              number: 11434
      # Summarization adapter
      - path: /summarization(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: ollama-summarization
            port:
              number: 11434
      # Default: route to base
      - path: /(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: ollama-base
            port:
              number: 11434
EOF

echo "✅ All remaining manifests generated!"
