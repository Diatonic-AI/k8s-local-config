# Llama3 8B External Access Configuration

**Last Updated:** 2025-10-02  
**LoadBalancer:** MetalLB v0.14.9  
**External IP:** 10.0.228.200  

---

## ✅ What Was Configured

### 1. MetalLB Load Balancer Installed

MetalLB provides external IP addresses for LoadBalancer services in your on-premises Kubernetes cluster.

- **Namespace:** `metallb-system`
- **IP Pool:** `llama3-pool`
- **IP Range:** `10.0.228.200 - 10.0.228.250` (50 IPs available)
- **Mode:** Layer 2 (L2Advertisement)
- **Status:** ✅ Active and healthy

```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

---

### 2. Ingress Controller Converted to LoadBalancer

The NGINX Ingress Controller was changed from NodePort to LoadBalancer type.

**Before:**
- Type: NodePort
- Access: `http://node-ip:30080` or `https://node-ip:30443`

**After:**
- Type: LoadBalancer  
- External IP: `10.0.228.200`
- Access: `http://10.0.228.200` or `https://10.0.228.200`
- Ports: 80 (HTTP) and 443 (HTTPS) - standard ports!

```bash
# Check ingress controller
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

---

### 3. DNS Configuration Updated

Your `/etc/hosts` file was updated to point all Llama3 hostnames to the LoadBalancer IP.

```bash
# /etc/hosts entries
10.0.228.200 ai.local
10.0.228.200 llama3.local  
10.0.228.200 ollama-fast.local
10.0.228.200 llama3.daclab-ai.local
10.0.228.200 vllm.local
10.0.228.200 llama3-vllm.local
```

---

## 🌐 Access Methods

### Method 1: Using Friendly Hostnames (Recommended)

With the updated `/etc/hosts`, you can access services using friendly names:

```bash
# Direct ClusterIP (always works, internal only)
curl http://10.107.148.186:8080/health

# Via LoadBalancer IP with Host header
curl -H "Host: ai.local" http://10.0.228.200/health

# HTTPS with self-signed cert (skip verification)
curl -k -H "Host: ai.local" https://10.0.228.200/health
```

### Method 2: Direct LoadBalancer IP

```bash
# Access ingress controller directly
curl http://10.0.228.200

# With explicit Host header for routing
curl -H "Host: ai.local" http://10.0.228.200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama/Meta-Llama-3-8B-Instruct", 
       "messages": [{"role": "user", "content": "Hello!"}],
       "max_tokens": 50}'
```

### Method 3: Direct Service Access (ClusterIP - Internal)

**This method always works and doesn't require ingress:**

```bash
# Hybrid Proxy (OpenAI-compatible API)
curl http://10.107.148.186:8080/health
curl -X POST http://10.107.148.186:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "meta-llama/Meta-Llama-3-8B-Instruct",
       "messages": [{"role": "user", "content": "Hello"}],
       "max_tokens": 50}'

# Ollama Direct (Native API)
curl http://10.97.47.88:11434/api/tags
curl -X POST http://10.97.47.88:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3:8b", "prompt": "Hello", "stream": false}'

# Qdrant Vector Database
curl http://10.101.86.126:6333/collections
```

---

## 🔐 TLS/SSL Configuration

The ingress is configured with self-signed certificates managed by cert-manager.

### Current Status
- **Certificates:** Self-signed by `selfsigned-cluster-issuer`
- **Hosts:** ai.local, llama3.local, ollama-fast.local, etc.
- **Status:** Certificates are being generated (may take a few minutes)

### Using HTTPS with Self-Signed Certs

```bash
# Skip certificate verification (-k flag)
curl -k https://ai.local/health

# Or accept the self-signed certificate in your browser
# and navigate to: https://ai.local
```

### Check Certificate Status

```bash
kubectl get certificates -n llama3-multi-adapter
kubectl describe certificate hybrid-proxy-tls -n llama3-multi-adapter
```

---

## 📊 Service Endpoints Summary

| Service | Internal (ClusterIP) | External (via LoadBalancer) | Protocol |
|---------|---------------------|----------------------------|----------|
| **Hybrid Proxy** | `10.107.148.186:8080` | `http://ai.local` | HTTP/HTTPS |
| **Ollama Direct** | `10.97.47.88:11434` | `http://ollama-fast.local` | HTTP/HTTPS |
| **Qdrant** | `10.101.86.126:6333` | Not exposed via ingress | HTTP |

---

## 🧪 Testing External Access

### Test 1: Health Check

```bash
# Via LoadBalancer with Host header
curl -H "Host: ai.local" http://10.0.228.200/health

# Should return:
# {"status": "healthy", "service": "hybrid-proxy"}
```

### Test 2: AI Query

```bash
# Via LoadBalancer
curl -X POST -H "Host: ai.local" http://10.0.228.200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "What is 2+2?"}],
    "max_tokens": 50,
    "temperature": 0.7
  }' | jq -r '.choices[0].message.content'
```

### Test 3: Direct ClusterIP (Always Works)

```bash
# This bypasses ingress completely
curl -X POST http://10.107.148.186:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 20
  }' | jq .
```

---

## 🔧 Troubleshooting

### Issue 1: "308 Permanent Redirect" or TLS Redirect

**Cause:** Ingress is configured to redirect HTTP to HTTPS.

**Solutions:**
1. Use HTTPS: `curl -k https://ai.local/health`
2. Use ClusterIP directly: `curl http://10.107.148.186:8080/health`
3. Remove TLS redirect annotation (not recommended for production)

### Issue 2: No Response or Connection Refused

**Check these:**

```bash
# 1. Verify MetalLB is running
kubectl get pods -n metallb-system

# 2. Check LoadBalancer IP assignment
kubectl get svc ingress-nginx-controller -n ingress-nginx

# 3. Verify ingress backend pods are ready
kubectl get pods -n llama3-multi-adapter | grep hybrid

# 4. Check ingress status
kubectl get ingress -n llama3-multi-adapter
```

### Issue 3: Certificate Errors

```bash
# Check certificate status
kubectl get certificates -n llama3-multi-adapter

# View certificate details
kubectl describe certificate hybrid-proxy-tls -n llama3-multi-adapter

# Force certificate renewal
kubectl delete certificate hybrid-proxy-tls -n llama3-multi-adapter
# It will be recreated automatically
```

---

## 📱 Accessing from Other Machines

To access from other machines on your network:

### Option 1: Update Their DNS

On each client machine, add to `/etc/hosts`:

```bash
10.0.228.200 ai.local
10.0.228.200 llama3.local
10.0.228.200 ollama-fast.local
```

### Option 2: Use IP Directly

```bash
# From any machine on the 10.0.228.x network
curl -H "Host: ai.local" http://10.0.228.200/health
```

### Option 3: Setup Local DNS Server

Configure a local DNS server (like dnsmasq or Pi-hole) to resolve `*.local` domains to `10.0.228.200`.

---

## 🔄 Rolling Back to NodePort

If you need to revert to NodePort access:

```bash
# Convert back to NodePort
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec": {"type": "NodePort"}}'

# Access will then be via:
# http://10.0.228.180:30080  (HTTP)
# https://10.0.228.180:30443 (HTTPS)
```

---

## 📚 Additional Configuration Files

### MetalLB Configuration
**Location:** `/home/daclab-ai/k8s-local-config/k8s-manifests/metallb/metallb-config.yaml`

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: llama3-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.228.200-10.0.228.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: llama3-l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - llama3-pool
```

### Adding More LoadBalancer Services

To expose other services via LoadBalancer:

```bash
# Example: Expose Ollama directly
kubectl patch svc ollama-simple-fast -n llama3-multi-adapter \
  -p '{"spec": {"type": "LoadBalancer"}}'

# MetalLB will automatically assign the next available IP from the pool
```

---

## 🎯 Summary

✅ **MetalLB Installed:** Provides external IPs for LoadBalancer services  
✅ **LoadBalancer IP Assigned:** 10.0.228.200  
✅ **DNS Configured:** All `*.local` domains point to LoadBalancer  
✅ **Ingress Enabled:** HTTP/HTTPS access without NodePort numbers  
⚠️ **TLS Certificates:** Self-signed (use `-k` flag with curl)  

### Primary Access Methods

**Internal (Always Works):**
- Hybrid Proxy: `http://10.107.148.186:8080`
- Ollama: `http://10.97.47.88:11434`

**External (Via LoadBalancer):**
- HTTP: `http://ai.local` or `http://10.0.228.200` with Host header
- HTTPS: `https://ai.local` (with `-k` flag for self-signed cert)

---

**Next Steps:**
1. Test external access from another machine on your network
2. Consider installing a real SSL certificate (Let's Encrypt) for production use
3. Set up proper DNS server for your network
4. Configure firewall rules if needed

**Maintained by:** daclab-ai  
**Infrastructure:** Kubernetes on-premises with MetalLB LoadBalancer
