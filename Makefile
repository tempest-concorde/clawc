IMAGE_REGISTRY := quay.io
REGISTRY_USER := rh-ee-chbutler
IMAGE := clawc

verify:
	cosign verify \
		--key containers-policy/cosign.pub \
		$(IMAGE_REGISTRY)/$(REGISTRY_USER)/$(IMAGE):prod

dev:
	go install github.com/hairyhenderson/gomplate/v4/cmd/gomplate@latest

toml:
	gomplate -f config.toml.tmpl -o config.toml

iso: toml
	rm -rf output && mkdir output
	podman pull $(IMAGE_REGISTRY)/$(REGISTRY_USER)/$(IMAGE):latest
	podman pull registry.redhat.io/rhel10/bootc-image-builder:latest
	podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(CURDIR)/config.toml:/config.toml \
		-v $(CURDIR)/output:/output \
		registry.redhat.io/rhel10/bootc-image-builder:latest \
		--type iso $(IMAGE_REGISTRY)/$(REGISTRY_USER)/$(IMAGE):latest

qcow: toml
	rm -rf output && mkdir output
	podman pull $(IMAGE_REGISTRY)/$(REGISTRY_USER)/$(IMAGE):latest
	podman pull registry.redhat.io/rhel10/bootc-image-builder:latest
	podman run --rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v $(CURDIR)/config.toml:/config.toml:ro \
		-v $(CURDIR)/output:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		registry.redhat.io/rhel10/bootc-image-builder:latest \
		--local --type qcow2 \
		$(IMAGE_REGISTRY)/$(REGISTRY_USER)/$(IMAGE):latest
