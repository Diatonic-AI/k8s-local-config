# k8s-local-config

Kubernetes manifests and configuration for Diatonic AI local and cluster environments (dev/staging/prod).

## 📋 Overview

This repository contains production-ready Kubernetes manifests organized for multi-environment deployments including:
- Local development environments
- Development/staging clusters  
- Production deployments
- LLM model deployments (Llama 3, adapters)
- Supporting infrastructure (Qdrant, storage, networking)

## 📁 Contents

- **`k8s-manifests/`**: Primary manifests organized by application and environment
  - `llama3-8b-deployment/`: LLM deployment configurations with multi-adapter support
  - `certificate-manager/`: TLS certificate management and cluster issuers
- **`docs/`**: Project documentation, ADRs, and operational guides
- **`.github/`**: CI/CD workflows, issue templates, and repository governance
- **`reports/`**: Auto-generated validation reports and analysis

## 🚀 Getting Started

### Prerequisites

Required tools:
- `git` - Version control
- `kubectl` - Kubernetes CLI (v1.28+)
- `yamllint` - YAML linting
- `kubeconform` - Kubernetes manifest validation
- `kustomize` - (Optional) For overlay management
- `helm` - (Optional) For Helm charts

Install validation tools:
```bash
# Ubuntu/Debian
pip install yamllint
curl -sSL https://github.com/yannh/kubeconform/releases/download/v0.6.7/kubeconform-linux-amd64.tar.gz | tar -xz
sudo mv kubeconform /usr/local/bin/

# macOS
brew install yamllint kubeconform
```

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone git@github.com:diatonic-ai/k8s-local-config.git
   cd k8s-local-config
   ```

2. **Validate manifests**:
   ```bash
   yamllint -c .yamllint.yaml .
   kubeconform -summary k8s-manifests/**/*.yaml
   ```

3. **Apply to cluster** (example):
   ```bash
   # Review before applying!
   kubectl apply -f k8s-manifests/certificate-manager/
   kubectl apply -f k8s-manifests/llama3-8b-deployment/multi-adapter/
   ```

## 📚 Documentation

See the [`docs/`](docs/) directory for detailed documentation:
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Setup Guide](docs/SETUP.md)
- Documentation index and templates in `docs/_templates/`

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes
- `refactor:` - Code refactoring

### Pull Request Process

1. Create a feature branch from `main`
2. Make changes and validate locally
3. Update documentation if needed
4. Open PR with descriptive title and summary
5. Ensure CI passes (yamllint + kubeconform)
6. Request review from @diatonic-ai/platform-team

## 🔒 Security

**Important**: Never commit plaintext secrets!

- Use Kubernetes Secrets with encryption at rest
- Prefer Sealed Secrets or External Secrets Operator
- Store sensitive values in CI/CD secret management
- See [SECURITY.md](SECURITY.md) for full security policy

To report security vulnerabilities: security@diatonic.ai

## 📊 Validation & CI

All manifests are automatically validated on push/PR via GitHub Actions:
- YAML linting with yamllint
- Kubernetes schema validation with kubeconform
- Structure and best practices checks

View CI status: [Actions](../../actions)

## 📝 License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

## 🙋 Support

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)
- **Email**: engineering@diatonic.ai

---

*Maintained by Diatonic AI Platform Team*
