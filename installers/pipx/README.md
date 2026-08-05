# pipx installer

## Purpose

Installs a selected pipx release in an isolated system-wide virtual environment for expert developers building development-container images.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

`python3`, Python's `venv` module, `ln` and `readlink` must already be available. Run [`../apt-python/install.sh`](../apt-python/install.sh) before this installer; pip is not required, so `apt-python --without-pip` is supported.

## Usage

```text
install.sh [OPTIONS]
```

The default installs pipx 1.16.6 and excludes pipx releases and dependencies uploaded during the last seven days.

## Options

- `--pipx-version VERSION`: installs an exact numeric dotted pipx version. The default is 1.16.6; versions older than 1.16.0 are rejected because they cannot support the package installer's cooldown contract.
- `--minimum-release-age-days DAYS`: accepts an integer from 0 through 3650 and installs only pipx artifacts available for at least that many days. The default is 7 days.
- `--without-minimum-release-age`: explicitly disables the default supply-chain delay. It cannot be combined with `--minimum-release-age-days`.
- `--help`: prints help and exits without changing system state.

Each scalar option may be specified only once.

## Installed files and commands

- `/usr/local/lib/pipx/` contains the isolated pipx virtual environment.
- `/usr/local/bin/pipx` is a symbolic link to `/usr/local/lib/pipx/bin/pipx`.
- pip 26.2.1 is installed inside the environment as the pinned bootstrap package-manager version.

No user shell startup file or `PATH` setting is modified.

## Repeated invocation

**Single-instance and idempotent for an exact match.** Repeating the installed pipx version verifies and preserves the canonical environment and symbolic link. Requesting another version or finding incomplete or non-canonical state fails without overwriting it. Remove `/usr/local/lib/pipx` and `/usr/local/bin/pipx` intentionally before changing versions.

## Network sources and integrity

pip downloads pip and pipx from the configured Python package index, which defaults to `https://pypi.org/simple/`. Index content is mutable. TLS and package hashes from index metadata are verified by pip and are not disabled. The bootstrap pip version and default pipx version are exact pins; the installer must be updated and retested to advance them.

The minimum-release-age control passes pip's `--uploaded-prior-to=PnD` filter while installing pipx and its dependencies. It requires index upload-time metadata and reduces exposure to newly uploaded compromises, but does not establish that an older package is safe. The exact bootstrap pip package is installed before this control is available.

## Examples

Install the default pipx version after its Python prerequisite:

```bash
../apt-python/install.sh --without-pip
./install.sh
```

Select another supported exact release with a 14-day delay:

```bash
./install.sh --pipx-version 1.16.5 --minimum-release-age-days 14
```

Explicitly disable the delay when a recent exact release is intentionally required:

```bash
./install.sh --pipx-version 1.16.6 --without-minimum-release-age
```

## Known limitations

Only numeric dotted pipx versions are supported. The installer does not use Ubuntu's older pipx package, configure authenticated indexes, install applications, modify shell profiles or manage removal. Credentials must not be passed as installer arguments.
