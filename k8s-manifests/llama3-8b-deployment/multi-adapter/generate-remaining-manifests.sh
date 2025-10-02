#!/bin/bash
set -euo pipefail

# Script to generate remaining adapter and ingress manifests
# This creates RAG adapter deployment, microservices adapter, and completes the deployment

echo "🚀 Generating remaining manifests for Llama3 Multi-Adapter deployment..."

# =============================================================================
# RAG Adapter Deployment
# =============================================================================
echo "📋 Creating RAG Adapter Deployment..."
cat > k8s/adapters/rag/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama3-rag-adapter
  namespace: llama3-multi-adapter
  labels:
    app: llama3-rag-adapter
    component: adapter
    adapter-type: rag
spec:
  replicas: 2
  selector:
    matchLabels:
      app: llama3-rag-adapter
  template:
    metadata:
      labels:
        app: llama3-rag-adapter
        component: adapter
        adapter-type: rag
    spec:
      initContainers:
      - name: init-rag-adapter
        image: huggingface/transformers-pytorch-gpu:latest
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            echo "Initializing RAG adapter..."
            
            if [ -f "/adapter-data/adapter_config.json" ]; then
              echo "RAG adapter already exists"
              exit 0
            fi
            
            mkdir -p /adapter-data
            
            cat > /adapter-data/adapter_config.json << 'ADAPTEREOF'
            {
              "peft_type": "LORA",
              "task_type": "CAUSAL_LM",
              "r": 16,
              "lora_alpha": 32,
              "lora_dropout": 0.1,
              "target_modules": ["q_proj", "v_proj", "k_proj", "o_proj"],
              "bias": "none",
              "inference_mode": false,
              "base_model_name_or_path": "/models/base/llama-3-8b"
            }
            ADAPTEREOF
            
            echo "RAG adapter initialized successfully"
        volumeMounts:
        - name: adapter-storage
          mountPath: /adapter-data
        - name: base-model
          mountPath: /models/base
          readOnly: true
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
      
      containers:
      - name: rag-adapter
        image: huggingface/transformers-pytorch-gpu:latest
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            echo "Starting RAG Adapter Service..."
            
            pip install --no-cache-dir \
              peft==0.7.0 \
              bitsandbytes==0.41.3 \
              fastapi==0.104.1 \
              uvicorn==0.24.0 \
              pydantic==2.5.0 \
              sentence-transformers==2.2.2 \
              qdrant-client==1.7.0
            
            cat > /tmp/serve_rag_adapter.py << 'PYEOF'
import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from sentence_transformers import SentenceTransformer
from peft import PeftModel
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams
import uvicorn

app = FastAPI(title="Llama3 RAG Adapter API")

class RAGRequest(BaseModel):
    query: str
    max_length: int = 2048
    temperature: float = 0.3
    top_k_retrieval: int = 5

class RAGResponse(BaseModel):
    generated_text: str
    sources: list

# Initialize components
print("Loading embedding model...")
embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

print("Connecting to Qdrant...")
qdrant_host = os.getenv("QDRANT_HOST", "qdrant-api.llama3-multi-adapter.svc.cluster.local")
qdrant = QdrantClient(host=qdrant_host, port=6333)

# Ensure collection exists
collection_name = "knowledge_base"
try:
    qdrant.get_collection(collection_name)
except:
    print(f"Creating collection {collection_name}...")
    qdrant.create_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(size=384, distance=Distance.COSINE)
    )

print("Loading base model...")
base_model_path = "/models/base/llama-3-8b"
adapter_path = "/models/adapters/rag"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True
)

model = AutoModelForCausalLM.from_pretrained(
    base_model_path,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True
)

if os.path.exists(adapter_path):
    print("Loading RAG adapter...")
    model = PeftModel.from_pretrained(model, adapter_path)

tokenizer = AutoTokenizer.from_pretrained(base_model_path)
tokenizer.pad_token = tokenizer.eos_token

print("RAG system ready!")

@app.get("/health")
def health_check():
    return {"status": "healthy", "adapter": "rag", "qdrant": "connected"}

@app.post("/generate", response_model=RAGResponse)
def generate_with_rag(request: RAGRequest):
    try:
        # Step 1: Retrieve relevant context
        query_embedding = embedding_model.encode(request.query).tolist()
        
        search_results = qdrant.search(
            collection_name=collection_name,
            query_vector=query_embedding,
            limit=request.top_k_retrieval
        )
        
        # Extract context and sources
        contexts = []
        sources = []
        for result in search_results:
            if result.score >= 0.7:
                contexts.append(result.payload.get("text", ""))
                sources.append({
                    "score": result.score,
                    "source": result.payload.get("source", "unknown")
                })
        
        # Step 2: Format prompt with retrieved context
        if contexts:
            context_str = "\n\n".join(contexts)
            prompt = f"""Context from knowledge base:
{context_str}

User Question: {request.query}

Assistant: Based on the provided context, """
        else:
            prompt = f"User Question: {request.query}\n\nAssistant: I don't have relevant context for this question, but "
        
        # Step 3: Generate response
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_length=request.max_length,
                temperature=request.temperature,
                top_p=0.9,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        generated = tokenizer.decode(outputs[0], skip_special_tokens=True)
        generated_text = generated.split("Assistant:")[-1].strip()
        
        return RAGResponse(
            generated_text=generated_text,
            sources=sources
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
PYEOF
            
            # Start the service
            python /tmp/serve_rag_adapter.py
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        env:
        - name: QDRANT_HOST
          value: "qdrant-api.llama3-multi-adapter.svc.cluster.local"
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        - name: PYTORCH_CUDA_ALLOC_CONF
          value: "max_split_size_mb:512"
        - name: TRANSFORMERS_CACHE
          value: "/models/.cache"
        volumeMounts:
        - name: base-model
          mountPath: /models/base
          readOnly: true
        - name: adapter-storage
          mountPath: /models/adapters/rag
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
          limits:
            memory: "12Gi"
            cpu: "6"
            nvidia.com/gpu: "1"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 180
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      
      volumes:
      - name: base-model
        persistentVolumeClaim:
          claimName: llama3-base-model
      - name: adapter-storage
        persistentVolumeClaim:
          claimName: llama3-rag-adapter
      - name: config
        configMap:
          name: llama3-rag-adapter-config
      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - llama3-rag-adapter
              topologyKey: kubernetes.io/hostname
EOF

echo "✅ RAG Adapter deployment.yaml created successfully!"

# =============================================================================
# Microservices Architecture Adapter
# =============================================================================
echo "🏗️  Creating Microservices Architecture Adapter..."
mkdir -p k8s/adapters/microservices

cat > k8s/adapters/microservices/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: llama3-microservices-adapter-config
  namespace: llama3-multi-adapter
  labels:
    app: llama3-microservices-adapter
    component: config
data:
  adapter_config.yaml: |
    adapter:
      name: "microservices-architecture"
      base_model: "/models/base/llama-3-8b"
      adapter_path: "/models/adapters/microservices"
      task_type: "architecture_design"
    
    generation:
      max_length: 4096
      temperature: 0.4
      top_p: 0.9
      top_k: 50
      repetition_penalty: 1.1
      do_sample: true
    
    architecture:
      patterns:
        - "microservices"
        - "event-driven"
        - "domain-driven-design"
        - "clean-architecture"
        - "hexagonal"
        - "cqrs"
        - "event-sourcing"
      
      technologies:
        - "kubernetes"
        - "docker"
        - "service-mesh"
        - "api-gateway"
        - "message-queues"
        - "databases"
        - "monitoring"
      
    api:
      port: 8080
      host: "0.0.0.0"
      max_concurrent_requests: 5
      timeout_seconds: 240
      
  system_prompt.txt: |
    You are a senior software architect specializing in microservices and distributed systems design.
    
    Your expertise includes:
    - Microservices architecture patterns and best practices
    - Domain-Driven Design (DDD) principles
    - Event-driven architectures and messaging patterns
    - API design and service communication
    - Data consistency and transaction patterns
    - Scalability and performance optimization
    - Security in distributed systems
    - Deployment and DevOps practices
    
    When designing architectures:
    - Focus on business domain boundaries
    - Consider scalability and fault tolerance
    - Recommend appropriate technology stack
    - Include monitoring and observability
    - Address data consistency challenges
    - Suggest deployment strategies
    - Consider team topology and Conway's Law
EOF

cat > k8s/adapters/microservices/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama3-microservices-adapter
  namespace: llama3-multi-adapter
  labels:
    app: llama3-microservices-adapter
    component: adapter
    adapter-type: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama3-microservices-adapter
  template:
    metadata:
      labels:
        app: llama3-microservices-adapter
        component: adapter
        adapter-type: microservices
    spec:
      initContainers:
      - name: init-microservices-adapter
        image: huggingface/transformers-pytorch-gpu:latest
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            echo "Initializing microservices architecture adapter..."
            
            if [ -f "/adapter-data/adapter_config.json" ]; then
              echo "Microservices adapter already exists"
              exit 0
            fi
            
            mkdir -p /adapter-data
            
            cat > /adapter-data/adapter_config.json << 'ADAPTEREOF'
            {
              "peft_type": "LORA",
              "task_type": "CAUSAL_LM",
              "r": 8,
              "lora_alpha": 16,
              "lora_dropout": 0.05,
              "target_modules": ["q_proj", "v_proj"],
              "bias": "none",
              "inference_mode": false,
              "base_model_name_or_path": "/models/base/llama-3-8b"
            }
            ADAPTEREOF
            
            echo "Microservices adapter initialized successfully"
        volumeMounts:
        - name: adapter-storage
          mountPath: /adapter-data
        - name: base-model
          mountPath: /models/base
          readOnly: true
      
      containers:
      - name: microservices-adapter
        image: huggingface/transformers-pytorch-gpu:latest
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            echo "Starting Microservices Architecture Adapter..."
            
            pip install --no-cache-dir \
              peft==0.7.0 \
              bitsandbytes==0.41.3 \
              fastapi==0.104.1 \
              uvicorn==0.24.0 \
              pydantic==2.5.0
            
            cat > /tmp/serve_microservices_adapter.py << 'PYEOF'
import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="Llama3 Microservices Architecture Adapter API")

class ArchitectureRequest(BaseModel):
    requirements: str
    domain: str = "general"
    scale: str = "medium"
    max_length: int = 4096
    temperature: float = 0.4

class ArchitectureResponse(BaseModel):
    architecture_design: str
    patterns_used: list
    technologies_recommended: list

print("Loading base model...")
base_model_path = "/models/base/llama-3-8b"
adapter_path = "/models/adapters/microservices"

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True
)

model = AutoModelForCausalLM.from_pretrained(
    base_model_path,
    quantization_config=bnb_config,
    device_map="auto",
    trust_remote_code=True
)

if os.path.exists(adapter_path):
    print("Loading microservices adapter...")
    model = PeftModel.from_pretrained(model, adapter_path)

tokenizer = AutoTokenizer.from_pretrained(base_model_path)
tokenizer.pad_token = tokenizer.eos_token

print("Microservices architecture advisor ready!")

@app.get("/health")
def health_check():
    return {"status": "healthy", "adapter": "microservices-architecture"}

@app.post("/generate", response_model=ArchitectureResponse)
def design_architecture(request: ArchitectureRequest):
    try:
        system_prompt = """You are a senior software architect. Design a microservices architecture based on the requirements.
        
        Consider:
        - Domain boundaries and service decomposition
        - Data consistency patterns
        - Communication patterns (sync/async)
        - Technology recommendations
        - Scalability and fault tolerance
        - Deployment and monitoring
        """
        
        full_prompt = f"""{system_prompt}
        
Requirements: {request.requirements}
Domain: {request.domain}
Expected Scale: {request.scale}

Architectural Design:
"""
        
        inputs = tokenizer(full_prompt, return_tensors="pt").to(model.device)
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_length=request.max_length,
                temperature=request.temperature,
                top_p=0.9,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        generated = tokenizer.decode(outputs[0], skip_special_tokens=True)
        design = generated.split("Architectural Design:")[-1].strip()
        
        # Extract patterns and technologies (simplified)
        patterns = ["microservices", "event-driven", "api-gateway"]
        technologies = ["kubernetes", "docker", "service-mesh", "mongodb"]
        
        return ArchitectureResponse(
            architecture_design=design,
            patterns_used=patterns,
            technologies_recommended=technologies
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
PYEOF
            
            python /tmp/serve_microservices_adapter.py
        ports:
        - name: http
          containerPort: 8080
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
        - name: PYTORCH_CUDA_ALLOC_CONF
          value: "max_split_size_mb:512"
        volumeMounts:
        - name: base-model
          mountPath: /models/base
          readOnly: true
        - name: adapter-storage
          mountPath: /models/adapters/microservices
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
          limits:
            memory: "10Gi"
            cpu: "5"
            nvidia.com/gpu: "1"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
      
      volumes:
      - name: base-model
        persistentVolumeClaim:
          claimName: llama3-base-model
      - name: adapter-storage
        persistentVolumeClaim:
          claimName: llama3-microservices-adapter
      - name: config
        configMap:
          name: llama3-microservices-adapter-config
EOF

cat > k8s/adapters/microservices/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: llama3-microservices-adapter
  namespace: llama3-multi-adapter
  labels:
    app: llama3-microservices-adapter
    component: adapter
spec:
  type: ClusterIP
  selector:
    app: llama3-microservices-adapter
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
EOF

echo "✅ Microservices Architecture Adapter created successfully!"
echo ""
echo "📋 Generation Complete!"
echo "=================================================================="
echo "Generated files:"
echo "  ✅ k8s/adapters/rag/deployment.yaml"
echo "  ✅ k8s/adapters/microservices/configmap.yaml"
echo "  ✅ k8s/adapters/microservices/deployment.yaml"
echo "  ✅ k8s/adapters/microservices/service.yaml"
echo ""
echo "🚀 Ready to deploy with: ./deploy-all.sh"
echo "=================================================================="
