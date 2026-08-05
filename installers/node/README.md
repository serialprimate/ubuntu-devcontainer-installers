# Node.js installer

## Purpose

Installs a selected supported Node.js major release and its bundled npm for expert developers building development-container images.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`. Node.js 24 is the supported LTS line and Node.js 26 is the supported Current line.

## Prerequisites

`apt-get` and `dpkg-query` must be available. The Ubuntu packages `ca-certificates`, `curl` and `gnupg` must already be installed. Install them explicitly with [`apt-packages`](../apt-packages/README.md) so the consuming Dockerfile controls their layer and composition order.

## Usage

```text
install.sh [--node-version VERSION]
```

The default selector is `lts`, currently Node.js 24.

## Options

- `--node-version VERSION`: selects `24`, `26`, `lts` or `current`. `lts` resolves to 24 and `current` resolves to 26.
- `--help`: prints help and exits without changing system state.

`--node-version` may be specified only once. Aliases are resolved by this installer release and do not query mutable release metadata during installation.

## Installed files and commands

- `/usr/bin/node` and `/usr/bin/npm` are provided by NodeSource's `nodejs` package.
- `/usr/share/keyrings/nodesource.gpg` contains the verified NodeSource repository signing key.
- `/etc/apt/sources.list.d/nodesource.sources` selects the requested major from the NodeSource `nodistro` repository.

Recommended packages are not installed. Successful APT lifecycles clean `/var/lib/apt/lists` and the APT package cache.

## Repeated invocation

**Single-instance and idempotent for the selected major.** Repeating a request for the installed major refreshes its repository and leaves that major installed. A request for a different major fails before repository state changes; remove the existing Node.js package and installer-owned NodeSource files before intentionally changing major releases. Existing non-canonical NodeSource source files are treated as collisions and are not overwritten.

## Network sources and integrity

The installer uses `https://deb.nodesource.com/node_<major>.x` for Node.js. Its package index is mutable. APT verifies NodeSource metadata with a dedicated `Signed-By` keyring. The separately composed `apt-packages` invocation uses the image's configured Ubuntu sources and trusted keyrings.

The NodeSource key is downloaded over HTTPS from `https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key`. Before installation, its full primary fingerprint must equal `6F71F525282841EEDAF851B42F59B5F99B1BE0B4`; a mismatch fails closed.

## Examples

Install prerequisites and then the supported LTS line:

```bash
../apt-packages/install.sh \
    --package ca-certificates \
    --package curl \
    --package gnupg
./install.sh
```

Install the same prerequisites and then the supported Current line:

```bash
../apt-packages/install.sh \
    --package ca-certificates \
    --package curl \
    --package gnupg
./install.sh --node-version 26
```

## Known limitations

Only one Node.js major can occupy the system paths. The installer supports NodeSource's binary package rather than per-user version managers, source builds or end-of-life Node.js releases. The `lts` and `current` aliases change only through a reviewed installer release.
