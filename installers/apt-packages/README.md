# APT packages installer

## Purpose

Installs an explicitly requested literal collection of Ubuntu packages for expert developers building development-container images.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

`apt-get` must be available. This is an intrinsic Ubuntu base-image prerequisite.

## Usage

```text
install.sh (--package PACKAGE | --package-file PATH)...
```

At least one package is required. Arguments are validated before APT changes begin.

## Options

- `--package PACKAGE`: installs one APT package specification and may be repeated. Values may include an architecture suffix or exact version accepted by APT.
- `--package-file PATH`: reads one literal package specification per non-blank line and may be repeated. Whitespace is not trimmed, and comments or shell syntax are not interpreted.
- `--help`: prints help and exits without changing system state.

## Installed files and commands

The requested Ubuntu packages determine installed files and commands. Recommended packages are not installed. A successful invocation cleans `/var/lib/apt/lists` and the APT package cache.

## Repeated invocation

**Idempotent.** APT retains packages already at the requested version and installs any newly requested packages. Each invocation independently refreshes package metadata and cleans its APT state. Different package collections may be installed in successive invocations.

## Network sources and integrity

The installer uses only APT sources already configured in the image. Ubuntu repository URLs are mutable package indexes; APT verifies repository metadata and packages using the image's configured trusted keyrings. The installer does not add repositories or weaken APT verification.

## Examples

Install two packages:

```bash
./install.sh \
    --package ca-certificates \
    --package xz-utils
```

Install package specifications from a file:

```bash
./install.sh --package-file ./apt-packages.txt
```

## Known limitations

Package availability follows the configured Ubuntu 26.04 repositories. This installer does not add repositories, resolve package policy beyond APT's normal rules or support non-Ubuntu systems.
