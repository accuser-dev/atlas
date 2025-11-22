---
name: Bug Report
about: Report a bug or issue with the infrastructure
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

<!-- A clear and concise description of what the bug is -->

## Expected Behavior

<!-- What should happen? -->

## Actual Behavior

<!-- What actually happens? -->

## Steps to Reproduce

1.
2.
3.

## Environment

<!-- Check all that apply -->

- Component:
  - [ ] OpenTofu configuration
  - [ ] Docker images
  - [ ] CI/CD pipeline
  - [ ] Documentation
  - [ ] Other (specify):

- Service:
  - [ ] Caddy
  - [ ] Grafana
  - [ ] Loki
  - [ ] Prometheus
  - [ ] Network configuration
  - [ ] Storage volumes
  - [ ] Other (specify):

## OpenTofu Version

<!-- Output of `tofu version` -->

```
tofu version output here
```

## Error Messages/Logs

<!-- Include relevant error messages, logs, or tofu plan output -->

```
paste error messages here
```

## Configuration

<!-- Relevant parts of your configuration (redact sensitive information) -->

```hcl
# Paste relevant OpenTofu config here
```

## Possible Solution

<!-- Optional: Suggest a fix or reason for the bug -->

## Impact

<!-- How does this affect you? -->

- [ ] Blocking - Cannot proceed
- [ ] High - Significant disruption
- [ ] Medium - Workaround available
- [ ] Low - Minor inconvenience

## Additional Context

<!-- Add any other context, screenshots, or information about the bug -->

## Checklist

- [ ] I have searched for similar issues
- [ ] I have included all relevant error messages
- [ ] I have redacted sensitive information
- [ ] I have tested on the latest version
