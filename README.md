# clawc

Layered [bootc](https://containers.github.io/bootc/) image on top of `quay.io/rh-ee-chbutler/rhel-dev:prod` that installs [OpenClaw](https://github.com/openclaw/openclaw) -- a self-hosted AI assistant gateway with integrations for Signal, WhatsApp, Home Assistant, Spotify, Sonos, and Gmail.

All LLM backends (Ollama, vLLM, vLLM via LiteLLM) are remote. No GPU required on this host.

## Integrations

| Integration | Install Method | Config Required |
|---|---|---|
| Signal | signal-cli binary in `/opt` | Phone number, QR link or SMS registration |
| WhatsApp | `openclaw plugins install @openclaw/whatsapp` | QR auth, allowlist phone numbers |
| Home Assistant | Built-in (env vars only) | `HA_URL`, `HA_TOKEN` |
| Spotify | `openclaw skills install` post-deploy | Spotify Premium, API credentials |
| Sonos | sonoscli Go binary | LAN access to Sonos speakers |
| Gmail | google-cloud-cli (dnf) | GCP project, Gmail API, Pub/Sub, OAuth |

## LLM Backend Configuration

Edit `/etc/openclaw/openclaw.env` on the deployed system:

```bash
# Option 1: Ollama (remote)
OPENCLAW_API_BASE=http://your-ollama-host:11434/v1
OPENCLAW_MODEL=llama3.2

# Option 2: vLLM (remote, direct)
OPENCLAW_API_BASE=http://your-vllm-host:8000/v1
OPENCLAW_MODEL=meta-llama/Llama-3.2-8B-Instruct
OPENCLAW_API_KEY=dummy

# Option 3: vLLM via LiteLLM (remote)
OPENCLAW_API_BASE=http://your-litellm-host:4000/v1
OPENCLAW_MODEL=default
OPENCLAW_API_KEY=your-litellm-key
```

## Usage Modes

### Mode 1: Local CLI

OpenClaw runs as a systemd service (`openclaw.service`) listening on `localhost:18789`:

- `openclaw agent --message "..."` for single-turn
- `openclaw agent` for interactive session
- Web UI at `http://localhost:18789`

The gateway binds to loopback only. No external access.

### Mode 2: Tailscale Serve Gateway

```bash
systemctl enable --now openclaw-tailscale-serve.service
```

This runs `tailscale serve http://localhost:18789` which:

- Exposes OpenClaw at `https://<node>.ts.net` (TLS terminated by Tailscale)
- Only accessible to devices on the Tailnet
- Gateway remains bound to localhost

## Network Hardening

A custom firewalld zone (`tailscale`) is included at `/usr/lib/firewalld/zones/tailscale.xml`.

### Post-deployment firewalld setup

```bash
# Assign tailscale0 to the hardened zone
firewall-cmd --permanent --zone=tailscale --add-interface=tailscale0

# Ensure default zone drops everything (no OpenClaw ports)
firewall-cmd --permanent --zone=public --set-target=DROP

# Reload
firewall-cmd --reload
```

### How it works

- OpenClaw gateway binds to `localhost:18789` (never exposed on any interface directly)
- Tailscale Serve listens on tailscale0:443 and proxies to localhost:18789
- The `public` zone (all non-tailscale interfaces) has `target=DROP` -- no services exposed
- The `tailscale` zone only allows SSH and HTTPS (443 for Tailscale Serve)
- Outbound connections (to LLM backends, Home Assistant, etc.) are allowed by default (stateful firewall)

## Post-deployment Setup

### Signal

Register signal-cli with your phone number:

```bash
signal-cli -u +1YOURPHONE register
signal-cli -u +1YOURPHONE verify CODE
```

### WhatsApp

Scan QR code via `openclaw plugins configure whatsapp`.

### Home Assistant

Set env vars in `/etc/openclaw/openclaw.env`:

```bash
HA_URL=http://homeassistant.local:8123
HA_TOKEN=your-long-lived-access-token
```

### Spotify

```bash
openclaw skills install spotify
```

Configure API credentials in `~/.openclaw/openclaw.json`.

### Gmail

```bash
gcloud auth login
gcloud projects create openclaw-mail
gcloud services enable gmail.googleapis.com pubsub.googleapis.com
```

## Forking / Adapting

1. Generate a new cosign keypair: `cosign generate-key-pair`
2. Replace `containers-policy/cosign.pub` with your public key
3. Update `IMAGE_REGISTRY`, `REGISTRY_USER`, and `IMAGE` in Makefile and workflows
4. Update `containers-policy/policy.json` with your registry paths
5. Set up the required GitHub Actions secrets (see below)

## Required GitHub Actions Secrets

| Secret | Purpose |
|---|---|
| `REGISTRY_USER` | Quay.io username |
| `REGISTRY_PASSWORD` | Quay.io password/token |
| `RH_REGISTRY_USER` | registry.redhat.io username |
| `RH_REGISTRY_PASSWORD` | registry.redhat.io password |
| `RHT_ORGID` | Red Hat subscription org ID |
| `RHT_ACT_KEY` | Red Hat subscription activation key |
| `COSIGN_PRIVATE_KEY` | Cosign signing private key |
| `COSIGN_PASSWORD` | Cosign key password |
| `FG_PAT` | GitHub PAT for semantic release |

## Local Build

Set environment variables for kickstart template, then:

```bash
export USERNAME=youruser
export PASSWORD_HASH=$(openssl passwd -6)
export SSH_KEY_PATH=~/.ssh/id_ed25519.pub
export DOCKER_AUTH_PATH=~/.docker/config.json

make iso    # Build bootable ISO
make qcow   # Build qcow2 disk image
```

Requires RHEL subscription and Quay.io login for base image pull.

## Image Verification

```bash
cosign verify \
  --key containers-policy/cosign.pub \
  quay.io/rh-ee-chbutler/clawc:prod
```
