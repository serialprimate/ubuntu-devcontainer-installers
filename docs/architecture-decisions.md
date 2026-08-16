# Architecture decisions

This document records the rationale for durable product-shape decisions. Current user-facing support and usage are documented in the [repository README](../README.md), while recurring implementation requirements are defined in [Conventions](../CONVENTIONS.md).

## Canonical installers

The canonical product is a collection of explicit Bash installation programs rather than Dev Container Features. Keeping the installers independent of Feature metadata and option handling makes their command-line contracts directly usable and testable in Dockerfiles. Dev Container configuration and OCI distribution remain consumption mechanisms around those programs, not parallel implementations.

## Explicit composition

Consuming Dockerfiles install prerequisites and invoke installers in the required order. Installers do not infer or install unrelated toolchains. This keeps layer ownership, prerequisite selection and system changes visible to the consumer and avoids a hidden dependency framework.

## Collection release unit

The complete installer collection uses one Semantic Versioning release version and one OCI image. Independent installer versions or images would add publication and consumption complexity without a demonstrated need. The image preserves the source relationship between `installers/` and `lib/` so the packaged programs use the same bundled-library resolution tested in the repository.

## Remote installation boundary

The project does not provide a generic remote-script executor. Verifying a bootstrap script does not verify mutable programs or scripts that it subsequently downloads. The narrow `github-release` installer instead installs one caller-selected raw executable only after checking a caller-pinned SHA-256 digest. The security analysis and exact boundary are recorded in the [installation-script investigation](install-script-investigation.md).

## Service lifecycle composition

The collection includes `container-services` as a dedicated optional installer in the single collection release unit. It owns a stable root entrypoint, a read-only readiness/status interface and an atomic registration manifest; it does not install or infer services. Eligible service installers independently provide a root-owned adapter in `/usr/local/libexec/ubuntu-devcontainer-installers/services/` while retaining their direct manual lifecycle command. This optional interoperability does not create a hard dependency between installers.

Registration is consuming-Dockerfile runtime policy, not an installer option. The consumer supplies one complete ordered list with `container-services register --service NAME`; registration validates only fixed, root-owned project adapters and never scans executable drop-ins or accepts arbitrary paths. The stable `ENTRYPOINT ["container-services", "entrypoint", "--"]` metadata boundary is declared by the consuming Dockerfile because a build-time installer cannot safely merge image metadata.

The MVP excludes automatic installer registration, generated shell code, arbitrary adapter paths, third-party adapters, a preconfigured runtime base image, dependency sorting, parallelism, restart policy and a new process-supervisor dependency. Declaration order is sufficient for the initial explicit composition model: startup follows the visible list, rollback and normal shutdown run it in reverse, and the expert consumer remains responsible for selecting a valid service order without introducing a hidden dependency framework. The service design and operational boundaries are detailed in [Service lifecycle and privilege in development containers](service-lifecycle-and-privilege.md).
