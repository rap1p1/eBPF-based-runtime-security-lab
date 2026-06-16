# Contributing to eBPF Runtime Security Lab

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use the issue template when available
3. Include:
   - Description of the issue
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (K8s version, OS, kernel version)

### Submitting Changes

1. **Fork** the repository
2. **Create** a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make** your changes following our coding standards
4. **Test** your changes:
   ```bash
   # For policies
   kubectl apply --dry-run=server -f policies/your-policy.yaml
   
   # For scripts
   shellcheck scripts/your-script.sh
   bash -n scripts/your-script.sh
   ```
5. **Commit** with a descriptive message:
   ```bash
   git commit -m "feat: add network egress policy"
   ```
6. **Push** and create a Pull Request

### Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `test:` Adding or updating tests
- `refactor:` Code refactoring

### Policy Contributions

When adding new Kyverno policies:

1. Place the file in `policies/` directory
2. Include proper annotations:
   - `policies.kyverno.io/title`
   - `policies.kyverno.io/category`
   - `policies.kyverno.io/severity`
   - `policies.kyverno.io/description`
3. Exclude system namespaces (kube-system, tetragon, kyverno, monitoring)
4. Add test manifests in `manifests/` directory
5. Update README.md policy table

### Script Contributions

When adding new scripts:

1. Place in `scripts/` directory
2. Include header comment with description
3. Use `set -euo pipefail`
4. Include colored logging functions
5. Add cleanup steps
6. Test on a clean cluster

## Code of Conduct

- Be respectful and constructive
- Focus on the technical merits
- Welcome newcomers
- Follow the project's coding standards

## Questions?

Open a Discussion or reach out to the maintainers.
