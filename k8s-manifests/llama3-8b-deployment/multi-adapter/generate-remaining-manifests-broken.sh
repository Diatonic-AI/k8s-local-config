#!/bin/bash
set -euo pipefail

# Script to generate remaining adapter and ingress manifests
# This creates RAG adapter deployment, microservices adapter, and ingress configuration

echo "🚀 Generating remaining manifests for Llama3 Multi-Adapter deployment..."

# =============================================================================
# RAG Adapter Deployment
# =============================================================================
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
        image: huggingface/transformers-pytorch-gpu:4.38.0
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
            
            echo "RAG adapter initialized"
        volumeMounts:
        - name: adapter-storage
          mountPath: /adapter-data
        - name: base-model
          mountPath: /models/base
          readOnly: true
      
      containers:
      - name: rag-adapter
        image: huggingface/transformers-pytorch-gpu:4.38.0
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