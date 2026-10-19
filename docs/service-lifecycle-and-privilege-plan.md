# Completed service lifecycle and privilege implementation plan

## Historical status

The service-lifecycle feature was delivered in release `0.5.0`; release `0.5.1` corrected Docker-in-Docker readiness checks for the non-root development user. This document records the completed plan's coordination scope. It is not a current implementation checklist, a source of interface requirements or evidence that a later revision has passed qualification.

Current information has these owners:

- [Service lifecycle and privilege design](service-lifecycle-and-privilege.md): topology, alternatives, privilege reasoning and design boundaries.
- [Service-adapter conventions](../CONVENTIONS.md#service-adapters-and-runtime-orchestration): recurring interoperability and implementation requirements.
- [Container-services README](../installers/container-services/README.md): exact orchestration interfaces, installed files, state and operational examples.
- [Docker-in-Docker README](../installers/docker-in-docker/README.md) and [threat model](docker-in-docker-threat-model.md): daemon-specific operation, authority and residual risks.
- [Testing guide](testing.md#service-lifecycle-qualification): suite mappings, current commands and profile qualification.
- [Release guide](releasing.md): publication authority, verification and release evidence.

## Delivered coordination scope

The plan replaced development-user sudo startup with a root-owned service lifecycle and a non-root readiness barrier, while retaining complete manual Docker-in-Docker management for consumers that do not register a service. Service selection stayed explicit in the consuming Dockerfile rather than being inferred by an installer.

Delivery was coordinated across the following areas:

- Added `installers/container-services/install.sh`, its README and the bundled `container-services` runtime command within the existing installer collection, not a parallel runtime package.
- Added `installers/docker-in-docker/container-service` as a narrow adapter delegating to the existing `docker-in-docker` lifecycle implementation, with no hard dependency on the orchestrator.
- Generalised `lib/common.sh` parameter terminology to component-qualified use while retaining public helper names, diagnostic text and stream routing. Runtime installers received independently owned private copies rather than sharing an installed file or depending on retained build payloads.
- Coordinated installed-file collision checks, idempotence, trust validation, atomic publication and stopped/unregistered installation state with the public contracts and negative tests.
- Added the `container-services` unit and integration suites, retained manual daemon coverage, and extended Docker-in-Docker runtime and nested-daemon qualification for automatic management.
- Extended packaged-artefact expectations for the exact installer collection, executable modes, library resolution, adapter registration and runtime independence after payload removal. The root packaging Dockerfile already copied the installer and library trees, so no separate release unit or packaging mechanism was introduced.
- Updated architecture, conventions, installer documentation, the threat model, testing guidance and collection documentation together.
- Migrated public and private development profiles after the qualified release became available, replacing sudo startup with the root entrypoint and read-only readiness hook. The subsequent profile digest update consumed the `0.5.1` readiness fix.

The migration retained the Docker group, privileged outer-container boundary, dedicated anonymous data volume and `--rm` lifecycle. It did not revoke the `user` installer's public `--allow-passwordless-sudo` option or add adapters and orchestrator dependencies to installers that provide no service. No new external package, network source, service-manager dependency or runtime base image was part of the feature.

## Qualification and retained boundaries

The delivery scope included focused service and foundation tests, all installer suites affected by shared logging, complete source-tree and nested-daemon qualification, candidate OCI verification, and Dev Container CLI and supported-editor profile checks. Release qualification records, rather than this historical summary, are the evidence for a particular published revision; see the [release guide](releasing.md#qualification-record).

The detailed acceptance scenarios and controlled candidate-profile procedure are retained in the [testing guide](testing.md#service-lifecycle-qualification). The design's exclusions and their rationale are retained in [Keep interoperability narrow](service-lifecycle-and-privilege.md#keep-interoperability-narrow); they remain boundaries rather than approved follow-up work.
