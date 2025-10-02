# 🔐 cert-manager Setup for Kubernetes Cluster

**Purpose:** Install and configure cert-manager for automated SSL/TLS certificate management

**Target:** Control node at `10.0.228.180` (daclab-k8s)

---

## 📁 Files in This Directory

| File | Purpose |
|------|---------|
| `install-cert-manager.sh` | Installs cert-manager v1.13.3 with CRDs |
| `cluster-issuer-selfsigned.yaml` | Creates 3 ClusterIssuers (self-signed, Let's Encrypt staging/prod) |
| `llama3-certificate.yaml` | Certificate resource for llama3.daclab-ai.local |
| `deploy-all.sh` | Complete deployment script (runs all steps) |
| `README.md` | This file |

---

## 🚀 Quick Deployment

### Option 1: Copy Files and Run on Control Node (Recommended)

```bash
# 1. Copy certificate-manager directory to control node
scp -r /home/daclab-ai/k8s-local-config/k8s-manifests/certificate-manager daclab-k8s@10.0.228.180:~/

# 2. SSH to control node and run deployment
ssh daclab-k8s@10.0.228.180
cd ~/certificate-manager
./deploy-all.sh
```

### Option 2: Remote Execution via SSH

```bash
# From this machine (daclab-ai), deploy to control node
cd /home/daclab-ai/k8s-local-config/k8s-manifests/certificate-manager

# Copy files first
scp *.sh *.yaml daclab-k8s@10.0.228.180:~/cert-manager-deploy/

# Execute remotely
ssh daclab-k8s@10.0.228.180 'cd cert-manager-deploy && bash deploy-all.sh'
```

### Option 3: Manual Step-by-Step

```bash
# SSH to control node
ssh daclab-k8s@10.0.228.180

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for cert-manager pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Apply ClusterIssuers (copy content or scp file)
kubectl apply -f cluster-issuer-selfsigned.yaml

# Apply Certificate for Llama3
kubectl apply -f llama3-certificate.yaml
```

---

## 📊 Current Status

### What's Configured in Ingress
- ✅ Ingress exists: `llama3-multi-adapter-ingress`
- ✅ TLS section configured
- ✅ References secret: `llama3-tls-cert`
- ✅ Annotation: `cert-manager.io/cluster-issuer: letsencrypt-prod`

### What's Missing (Why SSL isn't working)
- ❌ cert-manager not installed
- ❌ ClusterIssuers not created
- ❌ Certificate resource not created
- ❌ TLS secret `llama3-tls-cert` doesn't exist

---

## 🔍 Verification Commands

After deployment, verify everything is working:

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuer

# Check Certificates
kubectl get certificate -n llama3-multi-adapter

# Check TLS Secret (should be auto-created by cert-manager)
kubectl get secret llama3-tls-cert -n llama3-multi-adapter

# Describe certificate for troubleshooting
kubectl describe certificate llama3-tls-cert -n llama3-multi-adapter
```

Expected output:
```
NAME                                 READY   SECRET              AGE
certificate.cert-manager.io/llama3-tls-cert   True    llama3-tls-cert     2m
```

---

## 🌐 Certificate Issuers Explained

### 1. Self-Signed Issuer (Default for local development)
- **Name:** `selfsigned-issuer`
- **Use Case:** Local development, internal testing
- **Pros:** Works immediately, no external dependencies
- **Cons:** Browser warnings (certificate not trusted)
- **Status:** ✅ Configured in `llama3-certificate.yaml`

### 2. Let's Encrypt Staging
- **Name:** `letsencrypt-staging`
- **Use Case:** Testing Let's Encrypt integration
- **Pros:** Free, automatic renewal, no rate limits
- **Cons:** Not trusted by browsers (staging CA)
- **Requirements:** Public domain, HTTP01 challenge reachable

### 3. Let's Encrypt Production
- **Name:** `letsencrypt-prod`
- **Use Case:** Production deployments with public domains
- **Pros:** Free, trusted by all browsers, automatic renewal
- **Cons:** Rate limits (5 certs/week per domain)
- **Requirements:** Public domain, HTTP01 challenge reachable
- **Status:** ⚠️ Referenced in ingress but won't work for `.local` domains

---

## ⚙️ Configuration Details

### Certificate Spec
```yaml
commonName: llama3.daclab-ai.local
dnsNames:
  - llama3.daclab-ai.local
  - "*.llama3.daclab-ai.local"  # Wildcard for subdomains
issuerRef:
  name: selfsigned-issuer
  kind: ClusterIssuer
secretName: llama3-tls-cert  # Auto-created by cert-manager
duration: 90 days
renewBefore: 15 days
```

### Why Self-Signed for `.local` Domains?

1. **Let's Encrypt won't work** for `.local` domains (they're not publicly routable)
2. **Self-signed is perfect** for internal/development use
3. **Browser warnings are expected** - add exception or import CA cert
4. **Encryption still works** - traffic is still TLS encrypted

---

## 🔧 Troubleshooting

### Certificate not issuing?

```bash
# Check certificate status
kubectl describe certificate llama3-tls-cert -n llama3-multi-adapter

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate request
kubectl get certificaterequest -n llama3-multi-adapter
```

### Common Issues

| Issue | Solution |
|-------|----------|
| CRDs not found | Wait 10 seconds after installing cert-manager |
| Certificate pending | Check ClusterIssuer exists and is ready |
| Secret not created | Check cert-manager logs for errors |
| Browser still warns | Normal for self-signed - add exception |

---

## 🚀 Post-Deployment Steps

### 1. Test HTTPS Access

```bash
# From any machine, test the endpoint
curl -k https://llama3.daclab-ai.local/health

# The -k flag skips certificate verification (needed for self-signed)
```

### 2. Add DNS Entry

Add to `/etc/hosts` on client machines:
```
10.0.228.180  llama3.daclab-ai.local
```

### 3. Trust Certificate (Optional)

For browsers to trust the certificate:

**Linux:**
```bash
# Get certificate
kubectl get secret llama3-tls-cert -n llama3-multi-adapter -o jsonpath='{.data.tls\.crt}' | base64 -d > llama3-cert.crt

# Install to system trust store
sudo cp llama3-cert.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**macOS:**
```bash
# Get certificate
kubectl get secret llama3-tls-cert -n llama3-multi-adapter -o jsonpath='{.data.tls\.crt}' | base64 -d > llama3-cert.crt

# Add to Keychain and trust
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain llama3-cert.crt
```

---

## 📈 Upgrading to Production Certificates

If you later get a public domain, switch to Let's Encrypt:

```bash
# Update certificate to use letsencrypt-prod
kubectl patch certificate llama3-tls-cert -n llama3-multi-adapter --type merge -p '
{
  "spec": {
    "issuerRef": {
      "name": "letsencrypt-prod"
    }
  }
}'

# cert-manager will automatically request new certificate
```

---

## 📚 Additional Resources

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)

---

**Created:** 2025-10-02  
**Version:** 1.0  
**Maintainer:** DAC Lab AI Team
