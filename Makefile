#!make

-include .env

# System
SHELL			= /bin/bash -ec

# Commands
DOCKER			?= docker
SED				?= sed
PRINTF			?= printf
GIT				?= git
GREP			?= grep

# Functions
define get_git_credential=
$(shell $(PRINTF) "%s\n%s" "host=github.com" "protocol=https" | $(GIT) credential fill | $(GREP) -oP '$1=\K\w+')
endef
define format_version=
$(shell $(SED) 's/v\{0,1\}\([0-9]*\..*\)/\1/g' <<< "$1")
endef

# Files
DOCKER_SOCK					?= /var/run/docker.sock

# Parameters
GITHUB_TOKEN				?= $(call get_git_credential,password)
IMAGE_NAME					?= ghcr.io/poweranimal/toolbox-image
IMAGE_BUILDER_IMAGE			?= $(shell $(GREP) -oP '(?<=FROM ).+(?= AS image-builder)' dep.dockerfile)
IMAGE_BUILDER_EXTRA_ARGS	?= -u root:root
CHECKED_BUILD_EXTRA_ARGS	?=
VERSION_APP					?= v0.0.0
VERSION_APP_IMAGE			?= $(shell $(SED) 's/v\{0,1\}\([0-9]*\..*\)/\1/g' <<< $(VERSION_APP))
DOCKER_USERNAME				?= $(call get_git_credential,username)
DOCKER_PASSWORD				?= $(call get_git_credential,password)
TARGET_PLATFORMS			?= linux/amd64

IMAGE_BUILDER_CMD = $(DOCKER) run --rm \
-v "$(PWD):/app:Z" \
-v "$(DOCKER_SOCK):/var/run/docker.sock:Z" \
-v "$(PWD)/.cache/trivy:/home/golane/.cache/trivy:Z" \
-e DOCKER_USERNAME=$(DOCKER_USERNAME) \
-e DOCKER_PASSWORD=$(DOCKER_PASSWORD) \
-e DOCKLE_TIMEOUT="10m" \
-e TRIVY_TIMEOUT="10m" \
$(IMAGE_BUILDER_EXTRA_ARGS) \
$(IMAGE_BUILDER_IMAGE)

.DEFAULT_GOAL = build

clean:
	$(RM) -rf .cache

define build_cmd=
$(IMAGE_BUILDER_CMD) \
checked-build \
$(CHECKED_BUILD_EXTRA_ARGS) \
$1 \
--platform "$(TARGET_PLATFORMS)" \
-t "$(IMAGE_NAME):latest" \
-t "$(IMAGE_NAME):$(VERSION_APP_IMAGE)" \
.
endef

build:
	@$(call build_cmd)
.PHONY: build

publish:
	@$(call build_cmd,--push)
.PHONY: publish

scan:
	@$(IMAGE_BUILDER_CMD) \
scan-image "$(IMAGE_NAME):$(VERSION_APP_IMAGE)"
.PHONY: scan
