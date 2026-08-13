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
