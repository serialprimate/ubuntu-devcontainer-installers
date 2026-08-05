# npm packages installer

## Purpose

Installs an explicit literal collection of global npm registry packages for expert developers building development-container images. Package lifecycle scripts are disabled by default and cannot be enabled by this installer.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

`npm` must already be available. Run [`../node/install.sh`](../node/install.sh) before this installer. The default minimum-release-age control requires npm 11.10.0 or newer.

## Usage

```text
install.sh --package PACKAGE [--package PACKAGE ...] [OPTIONS]
```

At least one package is required. Every `--package` contributes one literal value; values are not split, expanded or evaluated.

## Options

- `--package PACKAGE`: installs one registry package name or `name@version-or-tag`; may be repeated. Scoped names such as `@scope/name` and `@scope/name@version` are supported. URLs, Git sources, aliases, local paths, ranges containing whitespace and option-like values are rejected.
- `--minimum-release-age-days DAYS`: accepts an integer from 0 through 3650 and installs only releases available for at least that many days. The default is 7 days.
- `--without-minimum-release-age`: explicitly disables the default supply-chain delay. It cannot be combined with `--minimum-release-age-days`.
- `--help`: prints help and exits without changing system state.

Each release-age option may be specified only once.

## Installed files and commands

Requested packages are installed into npm's system-wide global prefix. Commands and files depend on the selected packages. npm package dependency lifecycle scripts are disabled with `--ignore-scripts`; packages that require installation scripts may be incomplete and are outside the current installer contract.

## Repeated invocation

**Multi-instance.** Separate invocations may add independent package sets to the same global npm prefix. Repeating an exact package version leaves that version selected. An unversioned name or mutable tag can resolve differently on a later invocation. Explicitly requesting the same package name with another version or tag allows npm to replace that package's global version; unrelated global packages are not removed.

## Network sources and integrity

npm uses its configured registry, which defaults to `https://registry.npmjs.org/`. Registry package metadata and unversioned selections are mutable. npm verifies package integrity using registry metadata and lockless global-install semantics; this installer does not disable TLS or integrity checks. Exact package versions improve reproducibility but are not a substitute for an immutable installer image or dependency review.

The minimum-release-age control asks npm to exclude versions published more recently than the selected number of days. It reduces exposure to newly published compromises but does not establish that an older package is safe.

## Examples

Install two exact package versions with the default seven-day delay:

```bash
./install.sh \
    --package typescript@5.9.2 \
    --package eslint@9.39.1
```

Use a 14-day delay:

```bash
./install.sh --package typescript@5.9.2 --minimum-release-age-days 14
```

Explicitly disable the delay when an unavailable recent version is intentionally required:

```bash
./install.sh --package typescript@latest --without-minimum-release-age
```

## Known limitations

Only registry package names with an optional simple version or tag selector are supported. The installer does not accept package-list files, configure registry authentication, persist npm configuration, remove packages or run package lifecycle scripts. Credentials must not be passed as installer arguments.
