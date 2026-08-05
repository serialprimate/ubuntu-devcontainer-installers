# Ubuntu Python installer

## Purpose

Installs Ubuntu's Python runtime and optional Ubuntu-packaged pip and virtual-environment tooling for expert developers building development-container images.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

`apt-get` must be available. This is an intrinsic Ubuntu base-image prerequisite.

## Usage

```text
install.sh [--without-pip] [--without-venv]
```

The default installs Python, pip and virtual-environment support.

## Options

- `--without-pip`: omits `python3-pip`.
- `--without-venv`: omits `python3-venv`.
- `--help`: prints help and exits without changing system state.

Each scalar option may be specified only once.

## Installed files and commands

- `python3` provides the Ubuntu Python interpreter.
- `python3-pip` provides pip unless `--without-pip` is selected.
- `python3-venv` provides the `venv` module unless `--without-venv` is selected.

Recommended packages are not installed. A successful invocation cleans `/var/lib/apt/lists` and the APT package cache.

## Repeated invocation

**Idempotent.** Repeating the same request leaves the selected Ubuntu packages installed. A later invocation may add omitted tooling, but omission does not uninstall packages installed previously. Every invocation independently refreshes and cleans APT state.

## Network sources and integrity

The installer uses only APT sources already configured in the image. Ubuntu repository URLs are mutable package indexes; APT verifies repository metadata and packages using the image's configured trusted keyrings. The installer does not add repositories or weaken APT verification.

## Examples

Install the default Python toolset:

```bash
./install.sh
```

Install only the Python runtime:

```bash
./install.sh --without-pip --without-venv
```

## Known limitations

Versions follow Ubuntu 26.04 package policy. This installer does not install pipx, PyPI packages, alternate Python versions or external repositories. Compose it with the dedicated [`pipx`](../pipx/README.md) and [`pipx-packages`](../pipx-packages/README.md) installers.
