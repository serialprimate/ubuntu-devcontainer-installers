# Architecture decisions

This document records the rationale for durable product-shape decisions. Current user-facing support and usage are documented in the [repository README](../README.md), while recurring implementation requirements are defined in [Conventions](../CONVENTIONS.md).

## Canonical installers

The canonical product is a collection of explicit Bash installation programs rather than Dev Container Features. Keeping the installers independent of Feature metadata and option handling makes their command-line contracts directly usable and testable in Dockerfiles. Dev Container configuration and OCI distribution remain consumption mechanisms around those programs, not parallel implementations.

## Explicit composition

Consuming Dockerfiles install prerequisites and invoke installers in the required order. Installers do not infer or install unrelated toolchains. This keeps layer ownership, prerequisite selection and system changes visible to the consumer and avoids a hidden dependency framework.

## Project-owned browser runtime

Browser support separates root-owned operating-system dependencies from project-owned application packages and browser binaries. A dependency installer selects a reviewed local package profile for an explicitly supported Playwright target; it does not discover dependencies upstream during installation, install a JavaScript toolchain or provide a shared browser service.

Projects select their npm packages and matching browsers and retain them in their existing workspace or local dependency tree. This avoids baking browser revisions into every development image or requiring a shared cache volume. It trades cross-project deduplication and offline image completeness for independent project lifecycle and space management. Consumers coordinate their image dependency target and project lockfile; a version selector is not automatic enforcement of later project upgrades or verification of downloaded browser archives. The [Playwright dependencies README](../installers/playwright-deps/README.md) owns the exact supported interface and operational consequences.

## Collection release unit

The complete installer collection uses one Semantic Versioning release version and one OCI image. Independent installer versions or images would add publication and consumption complexity without a demonstrated need. The image preserves the source relationship between `installers/` and `lib/` so the packaged programs use the same bundled-library resolution tested in the repository.

## Remote installation boundary

The project does not provide a generic remote-script executor. Verifying a bootstrap script does not verify mutable programs or scripts that it subsequently downloads. The narrow `github-release` installer instead installs one caller-selected raw executable only after checking a caller-pinned SHA-256 digest. The security analysis and exact boundary are recorded in the [installation-script investigation](install-script-investigation.md).

## Service lifecycle composition

The collection includes `container-services` as a dedicated optional installer in the single collection release unit, not a parallel runtime package or preconfigured base image. Eligible service installers provide adapters while retaining complete manual lifecycle control; this optional interoperability creates no hard dependency between installers.

Registration is consuming-Dockerfile runtime policy rather than an installer option. Explicit selection and declaration order keep service composition visible without a hidden dependency framework. The consumer also declares stable entrypoint metadata because a build-time installer cannot safely merge it. Root orchestration and non-root readiness observation separate service authority from development-user convenience without claiming that privileged Docker-in-Docker is strongly isolated.

[Service lifecycle and privilege in development containers](service-lifecycle-and-privilege.md) owns the detailed topology rationale, rejected alternatives and design boundaries. The [service-adapter conventions](../CONVENTIONS.md#service-adapters-and-runtime-orchestration) own recurring interoperability requirements, and the [container-services README](../installers/container-services/README.md) owns exact interfaces and runtime mappings.
