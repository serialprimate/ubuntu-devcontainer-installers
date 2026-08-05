# Development user installer

## Purpose

Establishes an explicit non-root development user and same-named primary group so bind-mounted files can use externally compatible numeric ownership in development containers.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. The installer must run as `root`.

## Prerequisites

Ubuntu account-management commands must be present. `--allow-passwordless-sudo` additionally requires the `sudo` package, including `visudo`; install it first with `apt-packages`.

Every requested shell and supplementary group must already exist. The consuming Dockerfile remains responsible for `USER`; Dev Container configuration remains responsible for `remoteUser` or `containerUser`.

## Usage

```text
install.sh [OPTIONS]
```

## Options

- `--username NAME`: user and primary-group name; default `dev`.
- `--uid ID`: numeric UID from 1 through 4294967294; default `1000`.
- `--gid ID`: numeric GID from 1 through 4294967294; default `1000`.
- `--shell PATH`: installed executable absolute login-shell path; default `/bin/bash`.
- `--group NAME`: existing supplementary group and may be repeated. Duplicate values have no additional effect.
- `--allow-passwordless-sudo`: explicitly enables unrestricted passwordless sudo after validating the rule with `visudo`.
- `--help`: prints help and exits without changing system state.

Scalar options may be specified only once. The installer intentionally has no password or password hash option because secrets must not be exposed through Docker image history.

## Installed files and commands

The installer creates:

- user `NAME` with home `/home/NAME`, the requested UID, GID and shell;
- primary group `NAME` with the requested GID; and
- `/etc/sudoers.d/NAME` at mode `0440` when `--allow-passwordless-sudo` is selected.

The sudo rule is `NAME ALL=(root) NOPASSWD: ALL`. It grants full root access without a password and is appropriate only when that development-container policy is intended.

## Repeated invocation

**Idempotent.** An account whose name, UID, GID, home, shell and same-named primary group already match is retained. Requested supplementary groups and sudo access are added; existing supplementary groups and an existing installer-compatible sudo rule are retained. Omitting a previously requested supplementary group or `--allow-passwordless-sudo` does not revoke that state.

A mismatched account occupying the requested name or UID is replaced. A mismatched group occupying the requested name or GID is replaced only when no account outside the replacement set still uses it. All discovered conflicts are checked before replacement begins. The installer refuses root identity conflicts, unexpected home paths, groups still required by other users and an existing different sudoers file.

Replacement runs `userdel --remove`: the replaced account's `/home/NAME` directory and mail spool are removed. Replacement is allowed only when the account's home is exactly `/home/NAME`; copy any needed files elsewhere before invoking the installer.

## Network sources and integrity

The installer performs no network access and adds no package source.

## Controlled-risk options

`--allow-passwordless-sudo` grants the development user unrestricted root access without authentication. Compromise of that user or any process running as it therefore compromises the whole container and any mounted credentials, sockets or files available to root. The installer warns immediately before writing the rule, and omission preserves the secure default of no sudoers entry.

This exception can be reasonable in a disposable, isolated development container whose workflow requires privilege changes. Prefer omitting sudo, running specific build steps as root before switching users or granting only narrowly selected commands in a separately managed sudoers policy. Avoid mounting sensitive host resources, and never use this option for production provisioning.

## Examples

Replace a default UID/GID 1000 account and establish `dev`:

```bash
./install.sh --username dev --uid 1000 --gid 1000
```

Add existing groups and sudo after installing the prerequisite:

```bash
../apt-packages/install.sh --package sudo
./install.sh \
    --username developer \
    --uid 1001 \
    --gid 1001 \
    --group adm \
    --group sudo \
    --allow-passwordless-sudo
```

## Known limitations

The installer does not migrate files from a replaced home, preserve a replaced account's memberships or manage runtime Dev Container user selection. It does not replace conflicts with nonstandard home paths because deleting those paths cannot be inferred to be safe.
