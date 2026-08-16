# Service lifecycle and privilege in development containers

## Status and scope

This document defines how consumers of this project manage services required by a development container without granting the development user unrestricted passwordless sudo. The `container-services` implementation and Docker-in-Docker adapter are present in the working tree but are not part of the released `0.4.0` OCI payload until the next qualified release.

The immediate example is the Docker-in-Docker daemon started by `.devcontainer/public/devcontainer.json`, but the decision applies more broadly to databases, caches and other long-running processes. It preserves the project's canonical product boundary: installers construct an image, while the consuming container definition owns runtime topology and startup policy.

## Findings

### Passwordless sudo is not a service manager

The current public and private profiles install `sudo`, grant `dev` `NOPASSWD: ALL`, and run `sudo docker-in-docker start` from `postStartCommand`. This is operationally simple, but it gives every process running as `dev` unrestricted root execution for the whole container lifetime. The authority is much broader than starting one reviewed daemon.

Removing sudo does not make Docker-in-Docker low privilege. The outer container remains privileged, and membership in the inner `docker` group grants administrative control through `/var/run/docker.sock`. As the existing [Docker-in-Docker threat model](docker-in-docker-threat-model.md) explains, a developer or compromised process with that socket can control the nested daemon. The worthwhile improvement is therefore least authority and clearer ownership, not a claim of strong isolation.

A command-specific sudoers rule would be narrower than `NOPASSWD: ALL` and is an acceptable migration fallback. It would still make a user lifecycle hook responsible for privileged startup, retain sudo as an image dependency and leave shutdown outside the command's ownership, so it is not the preferred end state.

### Lifecycle hooks and process lifecycle solve different problems

A Dev Container `postStartCommand` runs after each container start. The specification also provides `waitFor`; setting it to `postStartCommand` lets an implementation delay readiness until that hook completes. The default is `updateContentCommand`, so merely using a blocking `postStartCommand` does not by itself guarantee that all user-facing implementation steps wait for the service. See the Dev Container specification's [lifecycle definition](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-reference.md#lifecycle).

Lifecycle hooks run in the configured container or remote user context. `remoteUser` changes the user used by supporting tools and terminals, whereas `containerUser` changes the container-wide user. Neither property is a per-command privilege boundary.

An image `ENTRYPOINT` has the authority of the image or container user; it does not inherently run as root. A root bootstrap is possible in the current profiles only because their Dockerfiles do not set `USER` and their Dev Container definitions set `remoteUser: dev` rather than `containerUser: dev`. That distinction must remain explicit.

An entrypoint also does not, on its own, establish a Dev Container readiness barrier. The runtime regards the container as running once its main process starts, while daemon initialization can still be in progress. A separate readiness check remains necessary.

### An executable drop-in gateway is insufficient

A generic `/etc/entrypoint.d/*` gateway has the right high-level instinct—perform privileged initialization in a root-owned container lifecycle rather than through unrestricted user sudo—but should not be adopted:

- Alphabetical discovery hides service selection and ordering, contrary to this project's explicit-composition objective.
- Requiring every hook to background itself treats process launch as success and provides no common readiness contract.
- A shell that starts children and then `exec`s the normal command no longer owns graceful service shutdown and cannot report an unexpected daemon exit.
- `chmod` at runtime mutates configuration and can turn an accidentally writable file into executable code. Executability and root ownership should be established during the image build.
- A `start|stop|status` shape alone does not define foreground operation, dependency failure, readiness, restart policy, logs, signal forwarding or child reaping.
- An unbounded generic hook mechanism would become a second composition framework and broaden the product beyond small, explicit build-time installers.

Docker documents both the preference for separating concerns and the additional wrapper or process-manager responsibility when [running multiple processes in one container](https://docs.docker.com/engine/containers/multi-service_container/). Docker stop initially signals only the container's main process and later uses `SIGKILL` if it does not exit, so signal propagation and cleanup ownership cannot be omitted; see [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/).

## Recommended solution

Use a two-level policy.

### 1. Prefer a separate service container

Run a daemon as a separate Compose service when it does not need to share the development container's namespaces or installation state. This is the default for databases, queues, caches and similar infrastructure.

The service image then owns its normal root startup, foreground process, health check, restart behaviour and shutdown. The development container remains non-root and needs neither sudo nor an in-container service manager. Compose can order dependencies and wait for `service_healthy`; see Docker's [startup and shutdown order guidance](https://docs.docker.com/compose/how-tos/startup-order/).

This option provides the clearest lifecycle boundary and should be rejected only for a documented technical reason, not merely to keep all processes in one container.

### 2. For necessary co-location, use explicit declarative registration

Some services are intentionally coupled to the development container. The current Docker-in-Docker design is such an exception: it uses a local Unix socket, a dedicated anonymous volume and the privileged outer-container boundary documented by this project.

For this case, the collection provides a dedicated `container-services` installer that owns the fixed, reviewed orchestration command and entrypoint. Eligible service installers independently provide compatible adapters, and the consuming image explicitly registers installed services in the Dockerfile. Installation and runtime policy remain separate operations:

```dockerfile
RUN /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

ENTRYPOINT ["container-services", "entrypoint", "--"]
```

This is the complete composition example for the implemented MVP interface. Installing `container-services` and registering services in the same `RUN` is supported and preferred when the consumer wants one filesystem layer. The requested service adapters must have been installed earlier in that command chain or in an earlier layer. The `register` operation accepts an ordered list of known service names and writes validated, immutable configuration; it does not generate shell code. The fixed entrypoint reads only that configuration and never scans a general executable drop-in directory.

A service installer must always install its manual lifecycle command and compatible service adapter, but must not require `container-services`, register itself or automatically enable itself. The adapter contract is optional interoperability rather than a runtime dependency: manual `start`, `stop` and `status` remain complete when the consumer declines orchestration. In particular, an installer option such as `--enable-entrypoint` or `--enable-auto-start` is excluded because it would mix image installation with runtime policy. The separate registration command is the expert user's explicit direction and keeps the resulting service list visible in the consuming Dockerfile and build log.

The `container-services` installer must not install a requested daemon or infer registration. It installs the command, entrypoint support, runtime-state support and shared runtime logging library. `register` then validates that every requested adapter already exists and otherwise fails with an actionable message giving the required composition order. The installer must be idempotent so its command can be invoked immediately later in the same `RUN`; Docker discards the incomplete layer if registration fails.

The stable `ENTRYPOINT` declaration does not change when installers, installer options or registered services change. A build-time installer cannot set image metadata, so consumers of an arbitrary base image must declare this entrypoint once. Avoiding even that declaration would require a separately approved preconfigured base image or another metadata-composition mechanism.

### MVP service implementation specification

Yes, every installed service implementation needs one shared high-level contract. Without it, `container-services` would merely relocate inconsistent service behaviour behind a common command. For the MVP, each eligible installer must provide one adapter identified by the same documented service name used with `--service`. Adapters live as root-owned regular executables in the shared project provider directory `/usr/local/libexec/ubuntu-devcontainer-installers/services/`; this directory expresses an installer-collection compatibility contract rather than ownership by the optional `container-services` installer. Registration accepts only a service name and resolves it beneath this fixed directory, never an arbitrary executable path.

The adapter must be an executable program that accepts exactly one literal operation:

- `start`: requires root, starts the service, waits until it is functionally ready, and returns zero only when ready;
- `stop`: requires root, gracefully stops only the service instance owned by the adapter and returns zero when it is stopped; and
- `status`: performs no state change, is usable by the development user, and returns zero only when the owned service is running and functionally ready.

These operations are the shared service functions at the design level; they need not be shell functions and are not sourced into the orchestrator. An adapter may be the installer's existing lifecycle command or a narrow wrapper around it. Keeping the process boundary prevents one service implementation from changing orchestrator state.

The MVP deliberately trusts these installer-owned operations and does not impose internal startup, readiness or shutdown timeouts. A hanging operation can therefore delay attachment or leave shutdown to the outer container runtime's stop timeout and eventual `SIGKILL`; this limitation must be documented. Timeouts, restart policy, dependency graphs and third-party service adapters are deferred until there is evidence for their required semantics.

Each adapter must also satisfy these requirements:

1. **Fixed identity:** use one lowercase kebab-case service name and reject arguments other than the three operations.
2. **Owned state:** identify its own process and resources robustly and never stop a process based only on an unverified stale PID.
3. **Fail-closed startup:** reject missing privileges, mounts, prerequisites and conflicting live state before reporting success.
4. **Readiness semantics:** make `start` and `status` test functional usability rather than only PID or path existence.
5. **Repeated lifecycle:** define behaviour for repeated `start`, `stop` and `status`, including stale runtime files after forced termination.
6. **Immutable implementation:** install the adapter as a root-owned regular executable that is not writable by the development user; registration must reject symlinks, missing adapters and unsafe ownership or modes.
7. **Literal execution:** require no shell evaluation, caller-provided command or arbitrary executable path in the registration manifest.
8. **Diagnostics:** use service-qualified messages, return non-zero on failure and identify the service-specific log location when applicable.
9. **Manual equivalence:** use the same adapter operations for automatic and manual management so the two paths cannot drift.
10. **Logging contract:** follow the shared component-qualified diagnostic format and stream conventions defined below.

The applicable installer README must document the service name, adapter path, authority required by each operation, readiness definition, files and processes affected, logs, repeated-operation behaviour, failure recovery and exact `container-services register --service NAME` example. It must also show direct manual `start`, `stop` and `status` commands. This makes both the registered runtime policy and its implementation reviewable by the expert user.

### MVP registration and ordering

For the MVP, declaration order is sufficient and preferable to a hidden dependency system. One registration invocation defines the complete ordered service list:

```dockerfile
RUN container-services register \
    --service service-a \
    --service service-b
```

`container-services` starts services in declaration order and stops successfully started services in reverse declaration order. The expert user is responsible for selecting a valid order using each installer README. Registration must reject duplicate names, unknown or unsafe adapters, an empty service value, and an existing different manifest rather than merge implicit state. Repeating the identical complete registration is idempotent.

The manifest contains service names and order only; executable paths come from the fixed trusted adapter location. Registration writes it atomically as a root-owned regular file that is not writable by the development user. A single registration invocation represents complete desired state so ordering cannot depend on Docker layer history or several accumulating registration calls.

If a service fails during startup, the entrypoint must stop the services that started successfully, in reverse order, and exit non-zero without launching the main container command. During normal shutdown it must signal the main command and invoke every registered service `stop` operation in reverse order, continuing after a stop failure and preserving a non-zero failure result. Exit of the main command also initiates reverse service shutdown, after which the orchestrator returns the applicable main-command or lifecycle failure status. Dependency metadata and parallel startup are outside the MVP.

The entrypoint must run as root, enforce one orchestrator instance, preserve every command argument literally, retain ownership of signal handling and child reaping, and avoid assumptions about an editor-specific keepalive command. Service definitions and the generated manifest must be root-owned and non-writable after the image build. Startup and shutdown diagnostics go to container logs, while service-specific diagnostics remain at the paths documented by their installers.

The entrypoint and `wait` command need a minimal runtime-state protocol under an installer-owned `/run` directory. At each entrypoint invocation, it must invalidate stale state, publish startup success or failure atomically, and bind that state to the live orchestrator identity so a previous container start cannot satisfy readiness. Runtime state must be readable but not writable by the development user. Concurrent `wait` and aggregate `status` calls are readers only. If the fixed entrypoint is configured with no registration manifest, it must transparently run the main command without service management, and `wait` and aggregate `status` must succeed with an explicit no-services diagnostic.

A mature process supervisor is preferable if later requirements include process restart, dependency graphs, parallelism or untrusted adapters. Adding one would be a new runtime dependency and requires explicit approval under this project's dependency policy. The MVP must remain a narrow orchestrator for trusted project-owned lifecycle operations rather than evolve into a generic Bash init system.

### Shared logging and diagnostics

The runtime component and service adapters must use the repository's existing diagnostic shape:

```text
<component>: info: <message>
<component>: warning: <message>
<component>: error: <message>
```

Informational messages go to standard output; warnings and errors go to standard error. `container-services` is the component name for registration, orchestration, aggregate status and wait diagnostics. Each adapter uses its documented service name, such as `docker-in-docker`, so direct manual operation and automatic operation produce the same identifiable messages. Diagnostics must not contain credentials, tokens, environment values that may be secret or untrusted command arguments beyond what is necessary to identify a validation error.

The orchestrator logs high-level transitions: registration result during the build, ordered service startup, startup completion, rollback, main-command exit, reverse service shutdown and lifecycle failures. Adapters remain responsible for service-specific progress and errors. The orchestrator must preserve adapter output rather than capture and reformat it, and it must not emit a second generic error for an adapter failure unless it adds actionable orchestration context. `wait` must avoid repeated polling output and emit only its final ready, failed or no-services result. Explicit `status` reports each service once in declaration order and returns non-zero if any status operation fails.

[`lib/common.sh`](../lib/common.sh) already implements the required `log_info`, `log_warning`, `log_error` and `die` behaviour. The MVP should reuse those functions rather than introduce another format. Their current `installer_name` parameter and installer-specific descriptions should be generalised to `component_name` because the implementation is already suitable for both installers and runtime programs; this is a terminology enhancement, not a change to output or existing callers.

Runtime commands cannot assume that the OCI payload remains at the path from which an installer ran. Each installer that installs a runtime program must therefore install a private runtime copy of the project-owned logging library beside support files it owns: `container-services` installs its copy for the orchestrator, while a service installer installs its copy for its manual lifecycle command and adapter. Both copies come from [`lib/common.sh`](../lib/common.sh), so implementations are reused without giving independently optional installers ownership of the same installed file. A service remains manually usable when `container-services` is absent. Runtime programs must resolve their private copy from their installed layout and must not inline duplicate logging functions or source an undeclared host or build-payload location. Source-tree and packaged-artifact tests must exercise both bundled-source and installed-runtime resolution.

The common logging unit tests should be extended to describe component-qualified use while retaining exact output and stream assertions. Runtime unit and integration tests must assert component qualification, standard-output and standard-error routing, declaration-order messages, quiet waiting, failure context and the absence of duplicated generic errors. Timestamps and structured logging are outside the MVP; container runtimes can add timestamps without changing the stable program output contract.

### Readiness in Dev Container profiles

The profile should retain a non-privileged lifecycle command only as a readiness barrier:

- the root `container-services` entrypoint starts registered services;
- `postStartCommand` runs `container-services wait` as the development user; and
- `waitFor` is set to `postStartCommand` when registered services must be usable before the environment is presented as ready.

For the MVP, `container-services wait` waits without an internal timeout until entrypoint startup has either completed successfully or failed, then invokes each registered adapter's read-only `status` operation in declaration order. It must return non-zero if startup failed, the orchestrator exited or any service is not ready. It must not start, stop or modify a service.

The readiness barrier is intentionally retained even though each `start` operation waits for functional readiness. Container runtimes can permit exec operations after the entrypoint process starts but before service initialization completes, and Dev Container implementations need an explicit standard lifecycle barrier.

### Manual operation without registration

Service installation does not imply registration. If the expert user omits `container-services register`, no service is automatically started and the service adapter remains directly usable according to its installer README. For example:

```bash
sudo docker-in-docker start
docker-in-docker status
sudo docker-in-docker stop
```

These commands describe authority, not a requirement for unrestricted passwordless sudo. The consumer may use interactive sudo, a narrowly reviewed command-specific sudoers policy, a root terminal, or `docker exec --user root` according to its own development-container policy. Installer documentation must not imply that `NOPASSWD: ALL` is necessary. A user without an approved elevation path can inspect status but cannot manually start or stop a root service.

Automatic and manual control of the same service must not be mixed concurrently. Adapter ownership checks must reject a conflicting live instance, and the README must explain how to determine whether the service is registered and automatically managed.

## Project boundary and implementation

The orchestration mechanism is a dedicated `container-services` installer and runtime-composition component, not an option added independently to daemon installers. It affects the product shape and OCI payload, so its implementation is qualified by the updates to [architecture decisions](architecture-decisions.md), complete source-tree and packaged-layout tests and release qualification.

The detailed code, test, documentation, packaging, release and profile work is itemised in the [service lifecycle and privilege implementation plan](service-lifecycle-and-privilege-plan.md). If later installers provide services, each must adopt this document's adapter specification and documentation before it can be registered. The MVP intentionally provides no arbitrary hook path or third-party registration escape hatch.

## Pause, stop and restart behaviour

Docker pause freezes all processes in the container through the freezer cgroup; processes do not receive a catchable pause notification. On unpause, the same processes continue. Services should therefore not be stopped or started by pause handling, although network peers and wall-clock timeouts may observe the interruption. See [`docker container pause`](https://docs.docker.com/reference/cli/docker/container/pause/).

A graceful stop sends the configured stop signal to the main process. The root orchestrator must propagate shutdown and invoke each registered service's `stop` operation. The MVP has no internal timeout, so the outer runtime remains responsible for its stop timeout and eventual forced kill if an operation hangs. Without orchestration ownership, background daemons may receive only that forced kill.

Starting or restarting an existing stopped container runs its entrypoint again, so startup must tolerate installer-owned stale runtime files but must never overwrite evidence of a live conflicting process. A container created with `--rm` is removed after it exits rather than being restarted in place; its anonymous volumes are removed with it. Recreated profiles must therefore behave correctly from a fresh writable layer and fresh anonymous data volume.

A forced kill, runtime crash or host failure provides no cleanup opportunity. Correctness must not depend on `stop` always running. Persistent data formats must tolerate abrupt termination, and ephemeral PID files and sockets must be validated against live process identity on the next start.

## Decision summary

The effective solution is not generic automatic hooks. It is explicit runtime topology:

- separate service containers by default;
- separate service installation from ordered `container-services register --service NAME` declarations;
- use a fixed root orchestrator only for justified co-location;
- require documented project-owned `start`, `stop` and `status` adapters;
- use a non-root Dev Container lifecycle hook solely as a readiness barrier;
- preserve documented manual lifecycle commands when registration is omitted; and
- grant no unrestricted passwordless sudo merely for automatic service management.

This keeps privilege at container startup, makes service selection and ordering reviewable, handles readiness and shutdown as distinct requirements, and preserves the project's visible Dockerfile composition model.
