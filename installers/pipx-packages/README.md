# pipx packages installer

## Purpose

Installs an explicit literal collection of global PyPI applications through pipx for expert developers building development-container images. Each application receives an isolated virtual environment and system-wide exposed commands.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

`pipx` 1.16.0 or newer must already be available. Run [`../pipx/install.sh`](../pipx/install.sh) before this installer. The consuming Dockerfile must run [`../apt-python/install.sh`](../apt-python/install.sh), then `pipx`, then `pipx-packages`.

## Usage

```text
install.sh --package PACKAGE [--package PACKAGE ...] [OPTIONS]
```

At least one package is required. Every `--package` contributes one literal value; values are not split, expanded or evaluated.

## Options

- `--package PACKAGE`: installs one PyPI project name or exact `name==version`; may be repeated. URLs, VCS sources, local paths, extras, ranges and option-like values are rejected.
- `--cooldown-days DAYS`: accepts an integer from 0 through 3650 and ignores index artifacts uploaded fewer than that many days ago. The default is 7 days and requires pipx 1.16.0 or newer.
- `--without-cooldown`: explicitly disables the default supply-chain delay. It cannot be combined with `--cooldown-days`.
- `--help`: prints help and exits without changing system state.

Each cooldown option may be specified only once.

## Installed files and commands

pipx creates one environment per application under `/opt/pipx/venvs` and exposes application commands in `/usr/local/bin`. Manual pages supplied by applications may be exposed under `/usr/local/share/man`. Exact commands and files depend on the selected packages.

## Repeated invocation

**Multi-instance.** Separate invocations may add independent package names to global pipx state. Repeating an installed exact version, or an unversioned name already present, is idempotent. A request for another version of an installed normalized project name fails before package changes rather than overwriting it; use pipx's explicit upgrade or uninstall commands outside this installer when replacement is intended.

## Network sources and integrity

pipx uses the configured Python package index, which defaults to `https://pypi.org/simple/`. Index metadata and unversioned selections are mutable. pip verifies TLS and package hashes supplied by index metadata; this installer does not disable those checks. Exact package versions improve reproducibility but do not replace dependency review.

The cooldown asks pipx to ignore artifacts uploaded more recently than the selected number of days. It requires index upload-time metadata and reduces exposure to newly uploaded compromises, but does not establish that an older package is safe.

## Examples

Install two exact application versions with the default seven-day cooldown:

```bash
./install.sh \
    --package pycowsay==0.0.0.2 \
    --package isort==5.13.2
```

Use a 14-day cooldown:

```bash
./install.sh --package pycowsay==0.0.0.2 --cooldown-days 14
```

Explicitly disable the cooldown when a recent application is intentionally required:

```bash
./install.sh --package pycowsay --without-cooldown
```

## Known limitations

Only package names and optional exact versions are supported. The installer does not accept package files, URLs, VCS sources, extras, alternate index options, package injection, forced replacement, upgrades or removals. Credentials must not be passed as installer arguments.
