# syntax=docker/dockerfile:1
# check=error=true

# Provides the 0.5.1 installer payload by immutable release identity
FROM ghcr.io/serialprimate/ubuntu-devcontainer-installers@sha256:d57b09b76ec4914c949b32587ce3e9557e4022dba27564d28c95fccd674dbba1 AS installers

# Builds the public development environment on the supported Ubuntu release
FROM ubuntu:26.04

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copy the complete payload while preserving bundled-library paths
COPY --from=installers \
    /ubuntu-devcontainer-installers \
    /opt/ubuntu-devcontainer-installers

# Install Docker-in-Docker with its explicit repository prerequisites
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh

# Install general development utilities
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package fd-find \
        --package git \
        --package jq \
        --package less \
        --package openssh-client \
        --package ripgrep \
        --package tree \
        --package unzip \
        --package yq \
        --package zip

# Install linters and formatters from Ubuntu and npm
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package shellcheck \
        --package shfmt \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh \
        --node-version lts \
    && /opt/ubuntu-devcontainer-installers/installers/npm-packages/install.sh \
        --package markdownlint-cli2

# Establish the non-root development user without passwordless sudo
RUN /opt/ubuntu-devcontainer-installers/installers/user/install.sh \
        --username dev \
        --group docker

# Install and register the container-services runtime orchestrator as the final layer
RUN /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

# Start registered services as root and retain their lifecycle around the main command
ENTRYPOINT ["container-services", "entrypoint", "--"]

# Keep the orchestrator alive because Dev Container command replacement is disabled
CMD ["sleep", "infinity"]
