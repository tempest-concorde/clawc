# AGENTS.md

This repository builds a layered bootc container image for OpenClaw on RHEL 10.

## Repository Structure

- `Containerfile` - Layered image definition on top of `quay.io/rh-ee-chbutler/rhel-dev:prod`
- `openclaw/` - Systemd service units and environment configuration
- `firewalld/` - Custom firewalld zone for Tailscale network hardening
- `containers-policy/` - Cosign public key, sigstore policy, and registry configs
- `.github/workflows/` - CI/CD pipelines (build, release, PR validation, commitlint, scorecard)
- `config.toml.tmpl` - Kickstart template for ISO/qcow2 image generation

## Key Conventions

- CI/CD patterns are replicated from `rhel-dev` (same cosign key, action SHA pins, UBI9 builder, multi-arch matrix)
- No `make get-deps` step -- this image has no pre-build binary downloads (unlike rhel-dev)
- PR and create-release workflows require Quay.io login to pull the private base image
- OpenClaw gateway binds to localhost:18789; external access is only via Tailscale Serve
- All LLM backends are remote (no local GPU workloads)
