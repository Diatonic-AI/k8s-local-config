# Security Policy

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| others  | :x:                |

## Security Best Practices

### Secrets Management

**CRITICAL**: Never commit plaintext secrets to this repository.

✅ **DO**:
- Use Kubernetes Secrets with encryption at rest enabled
- Prefer Sealed Secrets (Bitnami) or External Secrets Operator
- Store sensitive values in secure secret management systems (Vault, AWS Secrets Manager, etc.)
- Use `kubectl create secret` or sealed-secrets for secret creation
- Add secrets patterns to `.gitignore`
- Use CI/CD secret management for automation credentials

❌ **DON'T**:
- Commit `.env` files with real credentials
- Hard-code API keys, tokens, or passwords in YAML
- Push kubeconfig files to the repository
- Share secrets via chat or email

### Pre-commit Hooks

Install git-secrets to prevent accidental secret commits:

```bash
# Install git-secrets
brew install git-secrets  # macOS
# or
apt-get install git-secrets  # Ubuntu/Debian

# Set up hooks
cd /path/to/k8s-local-config
git secrets --install
git secrets --register-aws
```

### Manifest Security

- Use `securityContext` to run containers as non-root
- Apply `PodSecurityPolicy` or `PodSecurityStandards`
- Limit container capabilities
- Use network policies to restrict traffic
- Scan images for vulnerabilities before deployment
- Keep base images updated

### RBAC

- Follow principle of least privilege
- Use specific service accounts per application
- Avoid cluster-admin role unless absolutely necessary
- Regularly audit RBAC permissions

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email security details to: **security@diatonic.ai**
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 5 business days
- **Status Updates**: Every 7 days until resolved
- **Resolution**: Depends on severity and complexity

### Disclosure Policy

- We'll coordinate disclosure timing with you
- Security advisories will be published after fixes are deployed
- Credit will be given to reporters (unless anonymity is requested)

## Security Scanning

This repository uses automated security scanning:

- **Dependabot**: Monitors dependencies for known vulnerabilities
- **CI/CD**: Validates manifests against security policies
- **Regular Audits**: Team conducts periodic security reviews

## Compliance

This repository follows:
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- NIST security guidelines where applicable

## Contact

For security questions or concerns:
- Email: security@diatonic.ai
- GitHub: @diatonic-ai/security-team

---

*Last updated: 2025-10-02*
