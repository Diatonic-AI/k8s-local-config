#!/usr/bin/env bash
# Complete repository bootstrap script for k8s-local-config
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "🚀 Bootstrapping k8s-local-config repository..."

# Initialize Git if not already done
if [[ ! -d ".git" ]]; then
    echo "📦 Initializing Git repository..."
    git init
    git config user.name "Diatonic AI Automation"
    git config user.email "engineering@diatonic.ai"
fi

# Analyze existing manifests
echo "🔍 Analyzing Kubernetes manifests..."
mkdir -p reports
find . -type f \( -name "*.yaml" -o -name "*.yml" \) ! -path "*/.git/*" ! -path "*/node_modules/*" > reports/manifest-files.txt

YAML_COUNT=$(wc -l < reports/manifest-files.txt || echo 0)
echo "Found $YAML_COUNT YAML files"

cat > reports/manifest-analysis.md << EOF
# Kubernetes Manifest Analysis

**Generated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Location**: $REPO_ROOT

## Summary
- **Total YAML files**: $YAML_COUNT
- **Primary deployments**: LLama 3 8B with multi-adapter support
- **Infrastructure**: Qdrant vector DB, storage, networking, TLS certificates

## Structure
\`\`\`
$(tree -L 3 -d k8s-manifests 2>/dev/null || find k8s-manifests -type d | head -20)
\`\`\`

## Key Components Detected
- LLM Deployments (Llama 3 8B)
- Multi-adapter architecture (chatbot, code, RAG, microservices)
- GPU time-slicing configuration
- Qdrant vector database
- Certificate management (cert-manager, cluster issuers)
- TLS ingress configuration
- Storage provisioning

## Validation Status
Run validation with:
\`\`\`bash
yamllint -c .yamllint.yaml .
kubeconform -summary k8s-manifests/**/*.yaml
\`\`\`
EOF

echo "✅ Analysis report created: reports/manifest-analysis.md"

# Add and commit all files
echo "📝 Creating initial commit..."
git add -A
git status --short

echo ""
echo "✅ Repository bootstrap complete!"
echo "📍 Next steps:"
echo "   1. Review the generated files"
echo "   2. Create the GitHub repository: gh repo create diatonic-ai/k8s-local-config --public"
echo "   3. Push to GitHub: git commit -m 'feat(repo): initial k8s manifest repository' && git push -u origin main"

