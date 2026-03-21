FROM quay.io/rh-ee-chbutler/rhel-dev:prod

# Node.js from RHEL AppStream
RUN dnf install -y nodejs npm && dnf clean all

# OpenClaw gateway
RUN npm install -g openclaw

# OpenClaw integration plugins
RUN openclaw plugins install @openclaw/whatsapp

# signal-cli (native Linux build for Signal integration)
ARG SIGNAL_CLI_VERSION=0.13.12
RUN ARCH=$(uname -m) && \
    curl -fsSL https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-${ARCH}.tar.gz \
    | tar -xz -C /opt && \
    ln -s /opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli /usr/local/bin/signal-cli

# sonoscli (Go binary for Sonos control - Go already in base)
RUN go install github.com/steipete/sonoscli/cmd/sonos@latest && \
    mv $(go env GOPATH)/bin/sonos /usr/local/bin/sonos

# Google Cloud SDK (for Gmail Pub/Sub integration)
RUN dnf install -y google-cloud-cli && dnf clean all

# Trust assets in /usr (read-only on bootc)
RUN mkdir -p /usr/share/pki/sigstore
COPY containers-policy/cosign.pub /usr/share/pki/sigstore/cosign.pub
RUN mkdir -p /usr/share/containers/registries.d
COPY containers-policy/quay.io-clawc.yaml /usr/share/containers/registries.d/quay.io-clawc.yaml
COPY containers-policy/quay.io-rhel-dev.yaml /usr/share/containers/registries.d/quay.io-rhel-dev.yaml

# Container image signature verification policy
COPY containers-policy/policy.json /etc/containers/policy.json

# OpenClaw systemd services
RUN mkdir -p /etc/openclaw
COPY openclaw/openclaw.service /usr/lib/systemd/system/openclaw.service
COPY openclaw/openclaw-tailscale-serve.service /usr/lib/systemd/system/openclaw-tailscale-serve.service
COPY openclaw/openclaw.env /etc/openclaw/openclaw.env

# Firewalld: custom tailscale zone (hardened)
COPY firewalld/tailscale.xml /usr/lib/firewalld/zones/tailscale.xml

# Enable OpenClaw gateway (runs on localhost:18789 by default)
RUN systemctl enable openclaw.service

RUN bootc container lint
