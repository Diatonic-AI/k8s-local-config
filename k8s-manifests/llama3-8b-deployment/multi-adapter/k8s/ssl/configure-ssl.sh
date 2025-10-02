#!/bin/bash
set -euo pipefail

BASE_DIR="/home/daclab-ai/k3s-multicloud-config/k3s-manifests/llama3-deployment/multi-adapter/ssl"

echo "🔐 Configuring SSL/TLS for Multi-Adapter Deployment"
echo "===================================================="
echo ""

# Prompt for domain name
read -p "Enter your domain name (e.g., ollama.yourdomain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain name is required"
    exit 1
fi

# Prompt for email
read -p "Enter your email for Let's Encrypt notifications: " EMAIL
if [ -z "$EMAIL" ]; then
    echo "❌ Email is required"
    exit 1
fi

# Ask if using staging or production
echo ""
echo "Choose Let's Encrypt environment:"
echo "  1. Staging (for testing, higher rate limits)"
echo "  2. Production (for real use, stricter rate limits)"
echo "  3. Self-signed (for local testing without domain)"
read -p "Enter choice (1-3): " ENV_CHOICE

case $ENV_CHOICE in
    1)
        ISSUER="letsencrypt-staging"
        echo "📝 Using staging environment"
        ;;
    2)
        ISSUER="letsencrypt-prod"
        echo "📝 Using production environment"
        ;;
    3)
        ISSUER="selfsigned-issuer"
        echo "📝 Using self-signed certificates"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🔧 Updating configuration files..."

# Update cluster-issuer.yaml with email
sed -i "s|admin@yourdomain.com|$EMAIL|g" "$BASE_DIR/cluster-issuer.yaml"

# Update ingress-tls.yaml with domain and issuer
sed -i "s|ollama.yourdomain.com|$DOMAIN|g" "$BASE_DIR/ingress-tls.yaml"
sed -i "s|letsencrypt-prod|$ISSUER|g" "$BASE_DIR/ingress-tls.yaml"

echo "✅ Configuration files updated"
echo ""

# Create deployment script
cat > "$BASE_DIR/deploy-ssl.sh" << 'DEPLOY_EOF'
#!/bin/bash
set -euo pipefail

echo "🚀 Deploying SSL/TLS Configuration"
echo "==================================="
echo ""

# Step 1: Install cert-manager (if not already installed)
echo "1️⃣  Installing cert-manager..."
if kubectl get namespace cert-manager &>/dev/null; then
    echo "   ✅ cert-manager already installed"
else
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    echo "   ⏳ Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=Available \
        deployment/cert-manager \
        deployment/cert-manager-webhook \
        deployment/cert-manager-cainjector \
        -n cert-manager \
        --timeout=300s
    
    echo "   ✅ cert-manager installed"
fi
echo ""

# Step 2: Apply ClusterIssuers
echo "2️⃣  Creating ClusterIssuers..."
kubectl apply -f cluster-issuer.yaml
echo "   ✅ ClusterIssuers created"
echo ""

# Step 3: Delete old non-TLS ingress if exists
echo "3️⃣  Removing old non-TLS ingress..."
kubectl delete ingress ollama-multi-adapter -n llama3-multi-adapter --ignore-not-found
echo "   ✅ Old ingress removed"
echo ""

# Step 4: Apply TLS-enabled ingress
echo "4️⃣  Deploying TLS-enabled ingress..."
kubectl apply -f ingress-tls.yaml
echo "   ✅ TLS ingress deployed"
echo ""

# Step 5: Wait for certificate
echo "5️⃣  Waiting for SSL certificate to be issued..."
echo "   This may take 1-2 minutes for Let's Encrypt validation..."
echo ""

for i in {1..60}; do
    CERT_STATUS=$(kubectl get certificate ollama-tls-cert -n llama3-multi-adapter -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    
    if [ "$CERT_STATUS" = "True" ]; then
        echo "   ✅ Certificate issued successfully!"
        break
    fi
    
    echo "   ⏳ Waiting for certificate... (${i}/60)"
    sleep 2
done

if [ "$CERT_STATUS" != "True" ]; then
    echo "   ⚠️  Certificate not ready yet. Check status with:"
    echo "      kubectl describe certificate ollama-tls-cert -n llama3-multi-adapter"
fi

echo ""
echo "📊 SSL/TLS Configuration Status"
echo "================================"
echo ""

echo "ClusterIssuers:"
kubectl get clusterissuer
echo ""

echo "Certificates:"
kubectl get certificate -n llama3-multi-adapter
echo ""

echo "Ingress:"
kubectl get ingress -n llama3-multi-adapter
echo ""

echo "TLS Secret:"
kubectl get secret ollama-tls-cert -n llama3-multi-adapter 2>/dev/null || echo "Secret not yet created"
echo ""

echo "🎉 SSL/TLS Deployment Complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Verify certificate: kubectl describe certificate ollama-tls-cert -n llama3-multi-adapter"
echo "  2. Test HTTPS endpoint: curl -v https://DOMAIN/base/api/tags"
echo "  3. Check certificate expiry: kubectl get secret ollama-tls-cert -n llama3-multi-adapter -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates"
echo ""
echo "🔗 HTTPS Endpoints:"
echo "  https://DOMAIN/base"
echo "  https://DOMAIN/chatbot"
echo "  https://DOMAIN/code"
echo "  https://DOMAIN/summarization"
DEPLOY_EOF

# Replace DOMAIN placeholder in deploy script
sed -i "s|DOMAIN|$DOMAIN|g" "$BASE_DIR/deploy-ssl.sh"
chmod +x "$BASE_DIR/deploy-ssl.sh"

echo "✅ Deployment script created: $BASE_DIR/deploy-ssl.sh"
echo ""
echo "📋 Configuration Summary"
echo "========================"
echo "Domain:        $DOMAIN"
echo "Email:         $EMAIL"
echo "Issuer:        $ISSUER"
echo ""
echo "🚀 To deploy SSL/TLS, run:"
echo "   cd $BASE_DIR"
echo "   ./deploy-ssl.sh"
echo ""
echo "⚠️  Important Notes:"
echo "  1. DNS must point $DOMAIN to your cluster's external IP"
echo "  2. Port 80 and 443 must be accessible from the internet"
echo "  3. For staging, certificates won't be trusted by browsers (testing only)"
echo "  4. For production, certificates will be trusted but have rate limits"
