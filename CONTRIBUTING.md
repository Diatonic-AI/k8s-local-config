# Contributing to k8s-local-config

Thank you for your interest in contributing! This document provides guidelines for contributing to this repository.

## Code of Conduct

This project adheres to the Contributor Covenant Code of Conduct. By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Search existing issues before creating a new one
- Provide clear reproduction steps for bugs
- Include relevant manifest snippets when applicable

### Pull Requests

1. **Fork and Clone**
   ```bash
   git clone git@github.com:YOUR_USERNAME/k8s-local-config.git
   cd k8s-local-config
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make Changes**
   - Follow existing patterns and conventions
   - Update documentation as needed
   - Test your changes locally

4. **Validate**
   ```bash
   yamllint -c .yamllint.yaml .
   kubeconform -summary k8s-manifests/**/*.yaml
   ```

5. **Commit**
   Use [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat(llama): add new adapter configuration
   fix(networking): correct ingress TLS settings
   docs(readme): update installation instructions
   chore(ci): update GitHub Actions workflow
   ```

6. **Push and Open PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then open a Pull Request on GitHub

### PR Checklist

- [ ] Changes follow existing code patterns
- [ ] yamllint passes without errors
- [ ] kubeconform validation passes
- [ ] Documentation updated (if applicable)
- [ ] Commit messages follow Conventional Commits
- [ ] PR description explains the changes clearly

## Development Setup

### Required Tools

- `git` - Version control
- `kubectl` - Kubernetes CLI
- `yamllint` - YAML linting
- `kubeconform` - Manifest validation
- `yq` - (Optional) YAML processing

### Local Validation

Before committing, always run:

```bash
# Lint YAML files
yamllint -c .yamllint.yaml .

# Validate Kubernetes manifests
kubeconform -summary -verbose k8s-manifests/**/*.yaml

# Check for secrets (use git-secrets or similar)
git secrets --scan
```

## Style Guidelines

### YAML Style

- Use 2 spaces for indentation
- Keep line length under 200 characters (warning level)
- Quote strings when necessary for clarity
- Use meaningful names for resources
- Add comments for complex configurations

### Resource Naming

- Use lowercase with hyphens: `llama3-adapter-chatbot`
- Include environment prefixes where applicable: `prod-llama3-service`
- Be consistent with naming across similar resources

### Documentation

- Update `docs/` when adding new features
- Keep ADR (Architecture Decision Records) for significant changes
- Use clear, concise language
- Include examples where helpful

## Review Process

1. Automated CI checks must pass
2. At least one team member review required
3. Address review feedback
4. Maintainer merges when approved

## Questions or Need Help?

- Open a GitHub Discussion
- Reach out to @diatonic-ai/platform-team
- Email: engineering@diatonic.ai

Thank you for contributing! 🙌
