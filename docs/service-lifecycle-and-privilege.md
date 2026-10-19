# Service lifecycle and privilege in development containers

## Purpose and authority

This document owns the rationale for service topology and privilege separation. The [service-adapter conventions](../CONVENTIONS.md#service-adapters-and-runtime-orchestration) own the recurring interoperability contract. The [container-services README](../installers/container-services/README.md) owns the exact orchestration CLI, paths, runtime state and operational behaviour; the [Docker-in-Docker README](../installers/docker-in-docker/README.md) owns its service-specific lifecycle and composition examples. Verification commands and suite mappings belong to the [testing guide](testing.md#service-lifecycle-qualification).

The `container-services` implementation and Docker-in-Docker adapter were introduced in `0.5.0`; `0.5.1` fixed Docker-in-Docker readiness checks for the non-root development user. The [completed implementation record](service-lifecycle-and-privilege-plan.md) describes that delivery, not outstanding work.

## Historical problem and alternatives

### Passwordless sudo is not a service manager

Before service orchestration was introduced, the development profiles installed `sudo`, granted `dev` `NOPASSWD: ALL`, and ran `sudo docker-in-docker start` from `postStartCommand`. This was operationally simple, but it gave every process running as `dev` unrestricted root execution for the whole container lifetime. The authority was much broader than starting one reviewed daemon.

The checked-in [public Dockerfile](../.devcontainer/public/Dockerfile) now installs and registers the orchestrator without granting passwordless sudo; its [Dev Container configuration](../.devcontainer/public/devcontainer.json) uses a non-root readiness hook instead of privileged startup. The `user` installer's explicit `--allow-passwordless-sudo` capability remains available for consumers whose broader development policy requires it; service orchestration does not require that exception.

Removing sudo does not make Docker-in-Docker low privilege. The outer container remains privileged, and membership in the inner `docker` group grants administrative control through `/var/run/docker.sock`. As the [Docker-in-Docker threat model](docker-in-docker-threat-model.md) explains, a developer or compromised process with that socket can control the nested daemon. The improvement is least authority and clearer ownership, not a claim of strong isolation.

A command-specific sudoers rule is narrower than `NOPASSWD: ALL` and remains an acceptable manual elevation choice. It would still make a user lifecycle hook responsible for privileged startup, retain sudo as an image dependency and leave shutdown outside the command's ownership, so it was not selected for automatic management.

### Lifecycle hooks and process lifecycle solve different problems

A Dev Container `postStartCommand` runs after each container start. Setting `waitFor` to `postStartCommand` lets an implementation delay readiness until that hook completes; the default is `updateContentCommand`. Merely using a blocking `postStartCommand` therefore does not by itself guarantee that all user-facing implementation steps wait for the service. See the Dev Container specification's [lifecycle definition](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-reference.md#lifecycle).

Lifecycle hooks run in the configured container or remote user context. `remoteUser` changes the user used by supporting tools and terminals, whereas `containerUser` changes the container-wide user. Neither property is a per-command privilege boundary.

An image `ENTRYPOINT` has the authority of the image or container user; it does not inherently run as root. The public profile can bootstrap services as root because its Dockerfile does not set `USER` and its Dev Container definition selects `remoteUser: dev` rather than `containerUser: dev`. An entrypoint also does not establish a Dev Container readiness barrier on its own: the runtime can permit exec operations while daemon initialisation is still in progress.

### Why not an executable drop-in gateway?

A generic `/etc/entrypoint.d/*` gateway would move privileged initialisation into the container lifecycle, but it would not solve the complete problem:

- Alphabetical discovery hides service selection and ordering, contrary to explicit composition.
- Requiring every hook to background itself treats process launch as success without a functional-readiness contract.
- A shell that starts children and then `exec`s the normal command no longer owns graceful service shutdown and cannot report an unexpected daemon exit.
- Runtime `chmod` mutates configuration and can turn an accidentally writable file into executable code; image construction is the appropriate point to establish trust and executability.
- A `start|stop|status` shape alone does not establish ownership, readiness, failure handling, restart policy, logs, signal forwarding or child reaping.
- An unbounded hook mechanism would become a second composition framework rather than a narrow interoperability boundary.

Docker explains the additional wrapper or process-manager responsibility when [running multiple processes in one container](https://docs.docker.com/engine/containers/multi-service_container/). Docker stop initially signals the container's main process and later uses `SIGKILL` if it does not exit, which makes signal propagation and cleanup ownership necessary; see [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/).

## Topology decision

### Prefer a separate service container

Run a daemon as a separate Compose service when it does not need to share the development container's namespaces or installation state. This is the default for databases, queues, caches and similar infrastructure. Co-location requires a documented technical reason, not merely a preference to keep all processes together.

The service image then owns its normal startup, foreground process, health check, restart behaviour and shutdown. The development container can remain non-root without sudo or an in-container service manager. Compose can order dependencies and wait for `service_healthy`; see Docker's [startup and shutdown order guidance](https://docs.docker.com/compose/how-tos/startup-order/).

### Use explicit registration for necessary co-location

Docker-in-Docker is an intentional exception because it uses a local Unix socket, a dedicated anonymous data volume and the privileged outer-container boundary. The dedicated optional `container-services` installer provides orchestration without changing the canonical product from image-building installers into a runtime base image.

Installation and runtime policy remain separate. A service installer supplies its manual lifecycle command and compatible adapter independently; the consuming Dockerfile selects services through explicit registration. A missing provider can therefore produce an actionable composition-order failure rather than trigger implicit installation. The [one-layer composition example](../installers/docker-in-docker/README.md#examples) keeps prerequisites, installation and registration visible in one cohesive `RUN` chain.

The consumer also declares stable entrypoint metadata once. Build-time installation cannot merge image metadata safely; avoiding that declaration would require a separately approved runtime base image or another metadata-composition mechanism. Service selection can change without changing the entrypoint itself.

### Keep interoperability narrow

The shared provider location is an installer-collection compatibility boundary, not ownership by the optional orchestrator. Adapters are separate executable programs rather than sourced shell functions, so a provider cannot accidentally change the orchestrator's shell state. A provider can delegate to its existing lifecycle command rather than maintain two implementations.

One registration invocation represents the complete ordered list. Declaration order makes the dependency decision reviewable without dependency metadata, topological sorting or accumulated Docker-layer history. For example, if a consumer selects a service before another service that relies on it, reverse shutdown releases the dependent service first; reverse rollback similarly unwinds only successful starts. The consumer remains responsible for choosing a valid order.

The [orchestration contract](../installers/container-services/README.md#runtime-operations) defines startup failure, rollback, signal forwarding, child reaping, main-command exit and shutdown behaviour. Its process-bound runtime state prevents a previous container start from satisfying readiness. Read-only `wait` and `status` separate observation from authority to start or stop services, and no-registration pass-through preserves the option not to orchestrate services at all.

The initial scope deliberately excludes automatic registration, installer entrypoint-enablement options, arbitrary adapter paths, executable drop-in discovery, generated shell code, third-party adapters, dependency graphs, parallel operations, automatic restart and a preconfigured runtime base image. It also excludes internal orchestration timeouts, timestamps and structured logging. These are design boundaries, not a backlog of approved features. A hanging trusted adapter can delay attachment or shutdown until the outer runtime forces termination.

A mature process supervisor is preferable if future requirements include restart, dependency graphs, parallelism or untrusted adapters. Such a dependency requires separate approval; the narrow orchestrator is not intended to evolve into a generic Bash init system.

### Reuse logging without coupling optional installers

Installation and runtime programs use the same component-qualified logging implementation in [`lib/common.sh`](../lib/common.sh). The internal parameter terminology was generalised from `installer_name` to `component_name` during implementation without changing public function names or output.

Each runtime installer owns a private installed copy of that library. This avoids both dependence on a build payload that consumers may remove and shared installed-file ownership between independently optional installers. A service remains manually usable when the orchestrator is absent. The [logging conventions](../CONVENTIONS.md#logging-and-diagnostics) define streams, secret handling and the boundary between adapter-specific diagnostics and actionable orchestration context.

## Operational implications

### Readiness is distinct from startup authority

The root entrypoint owns startup and shutdown; the non-root lifecycle hook only observes readiness. Even though service startup waits for functional readiness, an exec operation can begin before entrypoint initialisation finishes, so the explicit Dev Container readiness barrier remains necessary.

The [Dev Container configuration example](../installers/container-services/README.md#examples) shows the complete metadata relationship: preserve the entrypoint with `overrideCommand: false`, provide a long-running image `CMD`, retain a root container process user, select the development user through `remoteUser`, and use `postStartCommand` plus `waitFor` as the read-only barrier. Selecting a non-root `containerUser` would remove the startup authority the design requires.

### Manual management remains independent

Omitting registration leaves the service's manual lifecycle interface available. The [manual Docker-in-Docker example](../installers/docker-in-docker/README.md#usage) illustrates required authority, not a requirement for unrestricted passwordless sudo. A root terminal, interactive sudo, a narrowly reviewed sudoers policy or `docker exec --user root` can supply an approved elevation path; without one, the development user can inspect status but cannot start or stop the service.

Do not mix automatic and manual management of the same service concurrently. The installer README describes process ownership, stale-state recovery and the registration manifest used to identify automatic management.

### Pause, stop, restart and forced termination differ

Docker pause freezes all container processes through the freezer cgroup; they receive no catchable pause notification. Unpause resumes those same processes, so pause handling should not stop or restart services. Network peers and wall-clock timeouts may nevertheless observe the interruption; see [`docker container pause`](https://docs.docker.com/reference/cli/docker/container/pause/).

Graceful stop gives the orchestrator an opportunity to signal the main command and shut down services. The outer runtime still owns its stop timeout and eventual forced kill when a trusted operation hangs. Without lifecycle ownership, background daemons may receive only that forced kill.

Starting or restarting an existing stopped container runs its entrypoint again. Installer-owned stale PID files and sockets need validation against live process identity rather than blind reuse or removal. A container created with `--rm` is removed after exit instead of restarting in place; its anonymous volumes are removed with it. Recreated profiles therefore need to work from a fresh writable layer and data volume.

A forced kill, runtime crash or host failure offers no cleanup opportunity. Persistent data must tolerate abrupt termination, and correctness cannot depend on graceful `stop` always running. The [threat model](docker-in-docker-threat-model.md) records the remaining authority and failure risks.
