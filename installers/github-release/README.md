# GitHub Release installer

## Purpose

Install one exact raw executable asset from one exact GitHub Release after verifying a caller-pinned SHA-256 digest. The installer does not execute upstream installation scripts, resolve `latest`, select assets heuristically or extract archives.

This installer is for expert software developers constructing development-container images. It is not a general package manager or production provisioning mechanism.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`.

## Prerequisites

Run as root after installing `ca-certificates` and `curl`. The consuming Dockerfile owns this composition order:

```bash
installers/apt-packages/install.sh \
    --package ca-certificates \
    --package curl
```

The Ubuntu base image must also provide `coreutils` and `sed`, as it does by default.

## Usage

```text
install.sh \
    --repository OWNER/REPOSITORY \
    --release-tag TAG \
    --asset-name NAME \
    --sha256 DIGEST \
    --install-path PATH
```

All five installation options are required and may be specified only once. Inputs are literal values and are never split, expanded or evaluated as shell syntax.

## Options

- `--repository OWNER/REPOSITORY` selects one exact public GitHub repository.
- `--release-tag TAG` selects one exact release tag. `latest` and path separators are rejected.
- `--asset-name NAME` selects one exact raw executable filename. Paths and patterns are rejected.
- `--sha256 DIGEST` requires a full 64-character SHA-256 digest selected through independent review.
- `--install-path PATH` selects a normalized absolute destination beneath an existing root-owned directory that is not writable by group or other users.
- `--help` prints usage without changing state.

The installer always writes the destination as a root-owned executable with mode `0755`.

## Installed files and commands

The single file requested by `--install-path` is installed. Its command name and behaviour are properties of the selected upstream asset.

## Repeated invocation

The installer is idempotent for the same destination, content digest, mode and `root:root` ownership. It fails with status `2` when the destination exists with different content, type, mode or ownership. It never replaces conflicting state.

Different destination paths provide independent instances. The consuming project remains responsible for avoiding command-name and application-level conflicts.

## Network sources and integrity

The installer downloads only this exact URL shape:

```text
https://github.com/OWNER/REPOSITORY/releases/download/TAG/ASSET
```

It follows at most five HTTPS-only redirects, which GitHub normally uses to serve release assets from GitHub-operated object storage. TLS protects transport. The required caller-pinned SHA-256 authenticates the exact downloaded bytes independently of the mutable network response. Downloaded content is verified before the destination is created, and failure never falls back to unverified installation.

The GitHub API's reported asset digest and adjacent upstream checksum files may inform digest review, but the installer does not trust dynamically fetched metadata as its pin. It does not verify GitHub artifact attestations in this initial design.

Only the selected asset is covered. The installed executable may make mutable network requests when subsequently run; those are outside this installation operation.

## Examples

Install Brave Search CLI `v1.5.0` for `linux/amd64` using the digest published for that exact GitHub Release asset at the time of review:

```bash
installers/github-release/install.sh \
    --repository brave/brave-search-cli \
    --release-tag v1.5.0 \
    --asset-name bx-1.5.0-linux-amd64 \
    --sha256 823a86dfd06734fee84371e9b9c08a89dbad7691fbf43dad217a9c5658827fa0 \
    --install-path /usr/local/bin/bx
```

Review the repository identity, exact release, asset and digest before updating any pin. Do not replace the tag or asset with `latest` during an image build.

## Known limitations

- Only one raw executable asset is supported per invocation.
- Archives, packages, source builds and upstream installation scripts are unsupported.
- Private repositories and authenticated downloads are unsupported.
- Version discovery, update proposals, signatures and attestations are outside the initial interface.
- The installer cannot determine whether the selected executable is functionally appropriate or safe; expert review remains required.
