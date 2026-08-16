# Container services installer

## Purpose

Installs the fixed `container-services` runtime orchestrator for expert development containers that must co-locate explicitly selected service processes with their main command. It does not install a service, select an adapter or change image metadata.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. Installation and `register` and `entrypoint` operations require `root`. The `wait` and `status` operations are readable by the development user.

## Prerequisites

The installer requires the ordinary Ubuntu commands `cmp`, `install`, `mktemp`, `mv`, `stat` and `chown`. It performs no network access and installs no Ubuntu package. Install an eligible service adapter before registering it; for Docker-in-Docker, run [`docker-in-docker`](../docker-in-docker/README.md) first.

The consuming container must declare the stable root entrypoint and retain a root container process user. The development user must have the read-only access required by every registered adapter; for Docker-in-Docker this means membership in the inner `docker` group.

```dockerfile
ENTRYPOINT ["container-services", "entrypoint", "--"]
```

`remoteUser` may select a non-root development user for terminals and lifecycle hooks; do not set `containerUser` to that user when this entrypoint must start services.

## Usage

```text
install.sh
```

Register the complete ordered service list during the image build:

```text
container-services register --service NAME [--service NAME ...]
```

Run the stable entrypoint with a literal main command:

```text
container-services entrypoint -- COMMAND [ARGUMENT ...]
```

Use the non-root readiness barrier and immediate aggregate status command as follows:

```text
container-services wait
container-services status
```

## Options

The installer accepts only `--help`, which exits without changing system state. The runtime accepts `--help` alone. `--service` is repeatable, preserves declaration order and must be supplied at least once to `register`; values are not split or evaluated.

Service names must be one to 64 lowercase letters and digits separated by single hyphens, beginning and ending with a letter or digit. Duplicate names, missing values, arbitrary paths, traversal and unknown operations are rejected. Runtime exit statuses are `0` for success, `2` for CLI misuse, `3` for registration failure, `4` for startup or lifecycle failure, `5` for readiness or aggregate-status failure and `6` when the main command succeeds but service shutdown fails. The entrypoint otherwise preserves a non-zero main-command status and returns `130` or `143` when `INT` or `TERM` terminates orchestration.

## Installed files and commands

The installer owns these root-owned paths:

- `/usr/local/bin/container-services`, mode `0755`, is the stable runtime command;
- `/usr/local/libexec/ubuntu-devcontainer-installers/container-services/common.sh`, mode `0644`, is its private runtime copy of the project logger;
- `/etc/ubuntu-devcontainer-installers/container-services`, mode `0755`, stores configuration; and
- `/etc/ubuntu-devcontainer-installers/container-services/services`, mode `0644` after registration, contains one service name per line.

The runtime creates `/run/ubuntu-devcontainer-installers/container-services/` with mode `0755` and a root-owned mode `0644` state file while an orchestrator is active. State records the orchestrator PID, Linux process start time and `starting`, `ready`, `failed` or `stopped` lifecycle value. State is published atomically and readers never modify it.

Adapters are resolved only as `/usr/local/libexec/ubuntu-devcontainer-installers/services/NAME`. A trusted adapter is a root-owned regular executable with exact mode `0755`. It must accept exactly literal `start`, `stop` and `status` operations: `start` and `stop` require root, while `status` performs no state change and returns zero only for functional readiness.

## Repeated invocation

**Idempotent installation and complete-list registration.** Repeating the installer with canonical files retains them; a conflicting command, support directory, private library or configuration path is rejected rather than overwritten. An identical registration succeeds without rewriting the manifest. A different registration is rejected; it is never merged or silently replaced. Registration itself does not start a service.

The entrypoint starts adapters in declaration order and stops successfully started services in reverse order. Startup failure rolls back successfully started services in reverse order. Normal main-command exit or termination invokes every registered adapter's `stop` operation in reverse order and continues after a stop failure.

## Network sources and integrity

There are no network sources, downloaded files or external package dependencies. The runtime executes only root-owned adapters from the fixed provider directory and never discovers arbitrary executable drop-ins or generated shell code.

## Examples

Install Docker-in-Docker and the orchestrator, then register one service in one image layer:

```dockerfile
RUN /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

ENTRYPOINT ["container-services", "entrypoint", "--"]
```

For Dev Container readiness, keep the process user root, set `remoteUser` to the development user and use:

```json
{
  "postStartCommand": "container-services wait",
  "waitFor": "postStartCommand",
  "remoteUser": "dev"
}
```

Without a registration manifest, `entrypoint -- COMMAND` runs `COMMAND` transparently and no service is started. An installed service remains manually usable according to its own README. Automatic management does not require unrestricted passwordless sudo.

## Known limitations

The MVP trusts project-owned adapters and provides no dependency metadata, topological sorting, parallelism, restart policy, internal startup/readiness/shutdown timeout, structured logging, third-party adapter support or arbitrary adapter path. A blocking adapter can delay startup or shutdown until the outer container runtime's stop timeout and eventual forced termination. A forced termination cannot run cleanup; the next invocation validates process identity and discards stale state before starting.
