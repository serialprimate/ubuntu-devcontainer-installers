# Container services installer

## Purpose

Installs the fixed `container-services` runtime orchestrator for expert development containers that must co-locate explicitly selected service processes with their main command. It does not install a service, select an adapter or change image metadata.

This README owns the exact orchestration interface and installed layout. The recurring [service-adapter contract](../../CONVENTIONS.md#service-adapters-and-runtime-orchestration) and [logging contract](../../CONVENTIONS.md#logging-and-diagnostics) are defined in Conventions; the [service lifecycle design](../../docs/service-lifecycle-and-privilege.md) explains the topology and privilege decisions.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. Installation and `register` and `entrypoint` operations require `root`. The `wait` and `status` operations are readable by the development user.

## Prerequisites

The installer requires the ordinary Ubuntu commands `cmp`, `install`, `mktemp`, `mv`, `stat` and `chown`. It performs no network access and installs no Ubuntu package. Install an eligible service adapter before registering it; for Docker-in-Docker, run [`docker-in-docker`](../docker-in-docker/README.md) first.

The consuming container must declare the stable root entrypoint and retain a root container process user. The development user must have the read-only access required by every registered adapter; for Docker-in-Docker this means membership in the inner `docker` group.

Root service-entrypoint Dockerfile fragment:

```dockerfile
ENTRYPOINT ["container-services", "entrypoint", "--"]
```

`remoteUser` may select a non-root development user for terminals and lifecycle hooks; do not set `containerUser` to that user when this entrypoint must start services.

## Usage

Install the orchestration command without registering or starting services:

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

### Runtime operations

`register` validates the entire request before publishing its manifest. It accepts only trusted adapters in the fixed provider directory and reports missing or unsafe adapters with the required composition order. One invocation defines the complete desired list, with no duplicate names, blank entries, comments or executable paths. Repeating an identical list retains the manifest; a different list is rejected rather than merged or replaced. Registration logs the final order once and never starts a service. Installer command and private-library files are installed atomically with fixed ownership and modes; installation is immediately usable by `register` later in the same `RUN`.

`entrypoint` requires root and at least one literal main-command argument after `--`. It rejects a second live orchestrator, validates existing runtime state, removes safely identified stale state and publishes `starting` state for its own process identity. It starts adapters in declaration order and publishes `ready` only after all starts succeed. Startup failure rolls back only successfully started services, in reverse order, and exits without launching the main command.

After startup, the entrypoint launches the main command directly without shell evaluation and retains ownership of child waiting and `TERM`/`INT` forwarding. Normal or unsuccessful main-command exit initiates reverse shutdown. Termination is also forwarded to an active startup adapter or main command. Shutdown continues after a service stop failure and preserves the exit-status precedence documented under Options. Readiness state is marked stopped and removed on handled exit where signal delivery permits cleanup.

`wait` is read-only and polls quietly without an internal timeout while the matching live orchestrator is starting. It fails for missing, malformed, stopped or stale state, startup failure or a disappeared orchestrator. After `ready`, it invokes every adapter's `status` in declaration order and succeeds only if all are ready. It emits one final orchestration result rather than logging every poll; adapter diagnostics remain visible.

`status` is read-only and returns immediately rather than waiting. It reports and checks every registered service in declaration order, even after one fails, and returns non-zero if the orchestrator is not ready or any service fails its readiness check.

Without a registration manifest, `entrypoint -- COMMAND` executes the main command directly without managing services, while `wait` and `status` succeed with an explicit no-services diagnostic. An unsafe or malformed existing manifest is an error, not no-services mode.

## Options

The installer accepts only `--help`, which exits without changing system state. The runtime accepts `--help` alone. `--service` is repeatable, preserves declaration order and must be supplied at least once to `register`; values are not split or evaluated.

Service names must be one to 64 lowercase letters and digits separated by single hyphens, beginning and ending with a letter or digit. Duplicate names, missing values, arbitrary paths, traversal and unknown operations are rejected. Runtime exit statuses are `0` for success, `2` for CLI misuse, `3` for registration failure, `4` for startup or lifecycle failure, `5` for readiness or aggregate-status failure and `6` when the main command succeeds but service shutdown fails. The entrypoint otherwise preserves a non-zero main-command status and returns `130` or `143` when `INT` or `TERM` terminates orchestration.

## Installed files and commands

The installer owns these root-owned paths:

- `/usr/local/bin/container-services`, mode `0755`, is the stable runtime command;
- `/usr/local/libexec/ubuntu-devcontainer-installers/container-services/common.sh`, mode `0644`, is its private runtime copy of the project logger;
- `/etc/ubuntu-devcontainer-installers/container-services`, mode `0755`, stores configuration; and
- `/etc/ubuntu-devcontainer-installers/container-services/services`, mode `0644` after registration, contains one service name per line.

The runtime creates `/run/ubuntu-devcontainer-installers/container-services/` with mode `0755` and a root-owned mode `0644` file named `state` while an orchestrator is active. The file contains exactly one `pid=VALUE`, `start_time=VALUE` and `state=VALUE` field per line, with no duplicate or unknown fields. `start_time` is the Linux process start-time value; the lifecycle value is `starting`, `ready`, `failed` or `stopped`. Both PID and start time must match a live non-zombie process before its state can establish readiness. State is published atomically and readers never modify it.

Adapters are resolved only as `/usr/local/libexec/ubuntu-devcontainer-installers/services/NAME` under the recurring [service-adapter contract](../../CONVENTIONS.md#service-adapters-and-runtime-orchestration). Registration and runtime manifest loading require the provider directory to be root-owned mode `0755`, and each adapter to be a non-symlink regular executable owned by root with exact mode `0755`. Configuration and runtime directories use mode `0755`; the manifest and state use mode `0644`, are root-owned regular files and must not be symlinks.

## Repeated invocation

**Idempotent installation and complete-list registration.** Repeating the installer with canonical files retains them; a conflicting command, support directory, private library or configuration path is rejected rather than overwritten. An identical registration succeeds without rewriting the manifest. A different registration is rejected; it is never merged or silently replaced. Registration itself does not start a service.

A repeated entrypoint invocation rejects a matching live orchestrator. After a stopped container restarts, valid stale state can be discarded before startup; malformed or unsafe state fails closed and must be investigated before manual removal. See [Runtime operations](#runtime-operations) for ordering, rollback and shutdown semantics.

## Network sources and integrity

There are no network sources, downloaded files or external package dependencies. The runtime executes only root-owned adapters from the fixed provider directory and never discovers arbitrary executable drop-ins or generated shell code.

## Examples

After installing the [Docker-in-Docker prerequisites](../docker-in-docker/README.md#prerequisites) and copying the installer payload, use this Dockerfile fragment to install both components and register one service in one image layer:

```dockerfile
# Install both components before explicit service registration
RUN /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

ENTRYPOINT ["container-services", "entrypoint", "--"]
```

Dev Container readiness configuration fragment, retaining the root container process user and selecting `dev` for tools and lifecycle hooks:

```json
{
  "overrideCommand": false,
  "postStartCommand": "container-services wait",
  "waitFor": "postStartCommand",
  "remoteUser": "dev"
}
```

Dev Container implementations replace an image command by default. Set `overrideCommand` to `false` so they preserve the service entrypoint; the consuming image must provide a long-running `CMD`, such as `CMD ["sleep", "infinity"]`, for the entrypoint to own. Without a registration manifest, `entrypoint -- COMMAND` runs `COMMAND` transparently and no service is started. An installed service remains manually usable according to its own README. Automatic management does not require unrestricted passwordless sudo.

## Known limitations

The MVP trusts project-owned adapters and provides no dependency metadata, topological sorting, parallelism, restart policy, internal startup/readiness/shutdown timeout, structured logging, third-party adapter support or arbitrary adapter path. A blocking adapter can delay startup or shutdown until the outer container runtime's stop timeout and eventual forced termination. A forced termination cannot run cleanup; the next invocation validates process identity and discards stale state before starting.
