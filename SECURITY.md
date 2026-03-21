# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly by opening a private security advisory in this repository's Security tab.

Do not open public issues for security vulnerabilities.

## Image Signing

All release images are signed with [cosign](https://github.com/sigstore/cosign). The public key is available at `containers-policy/cosign.pub`.

Verify an image:

```bash
cosign verify \
  --key containers-policy/cosign.pub \
  quay.io/rh-ee-chbutler/clawc:prod
```

## Supply Chain Security

- All GitHub Actions are pinned to full commit SHAs
- OpenSSF Scorecard runs weekly
- SBOM (CycloneDX) and build provenance attestations are generated for every release
- Trivy vulnerability scanning runs on every release
- Container image signature verification policy rejects unsigned images by default

## Network Security

- OpenClaw gateway binds to `localhost:18789` only
- Inbound traffic is restricted to Tailscale interface via custom firewalld zone
- The `public` firewalld zone is configured with `target=DROP`
- Only SSH and HTTPS (443) are allowed on the tailscale zone
