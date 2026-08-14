# syntax=docker/dockerfile:1
# check=error=true

# Provides the qualified installer payload by immutable release identity
FROM ghcr.io/serialprimate/ubuntu-devcontainer-installers@sha256:535a0ee05cc8413b6bcde130df6750bb21fcb0929a472e95ab82adc49ac55dfa AS installers

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

# Establish the non-root development user with nested-daemon lifecycle authority
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package sudo \
    && /opt/ubuntu-devcontainer-installers/installers/user/install.sh \
        --username dev \
        --group docker \
        --allow-passwordless-sudo
