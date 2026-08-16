# Docker-in-Docker requirements and threat model

## Intended outcome

The Docker-in-Docker installer supports project integration tests inside a disposable Ubuntu 26.04 development container. It installs the official Docker Engine packages, leaves the daemon stopped after image construction and provides explicit `start`, `stop` and `status` operations.

The design must not mount a host Docker socket, create host-persistent named volumes, expose a TCP daemon endpoint or depend on a system service manager. Nested Docker state belongs to an anonymous outer-Docker volume mounted at `/var/lib/docker-in-docker`. The outer container must use `--rm`, which makes Docker remove the anonymous volume with that container. The dedicated backing mount lets the daemon use its supported default copy-on-write backend without unreliable overlay-on-overlay mounts.

The installer also provides the optional root-owned `docker-in-docker` adapter at `/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker`. `container-services` registration is separate policy: installing this adapter does not install, enable or register the orchestrator.

## Trust boundaries

The outer container runtime and host kernel enforce the only isolation boundary. The nested Docker daemon, its containers and all code run in the development container share the authority granted by the outer container's privileged mode. The local Unix socket is an administrative interface: access to it is equivalent to root authority inside the development container.

The official Docker APT repository is a separately trusted network source. TLS protects transport and APT verifies repository metadata and packages with the fingerprint-pinned Docker signing key. Package versions remain selected from a mutable stable repository, consistent with the other external APT installers in this collection.

## Threats and controls

| Threat | Control | Residual risk |
| --- | --- | --- |
| Privileged nested daemon escapes the development container | Restrict use to trusted, disposable development contexts; require explicit outer-container privilege | A daemon, runtime or kernel vulnerability may compromise the host |
| Host daemon compromise through socket mounting | Use a newly started inner daemon and reject an existing `/var/run/docker.sock` | Privileged mode remains broad even without a host socket |
| Remote daemon access | Bind only the local Unix socket; configure no TCP listener | Members of the inner `docker` group have daemon-equivalent authority |
| Unexpected persistent state | Require an anonymous data volume and outer `--rm`; project cleanup removes matching containers with their anonymous volumes | An interrupted outer runtime can retain both container and volume until labelled cleanup runs |
| Unintended startup | Do not start the daemon during installation; require an explicit lifecycle command | Abrupt outer-container termination can bypass graceful shutdown |
| PID-file reuse stops an unrelated process | Verify the recorded PID is live, identifies `dockerd`, uses the managed data root and PID file, and has a matching Docker API | Process identity checks cannot provide cryptographic ownership |
| Trusted adapter is replaced or invokes an unintended path | Install the adapter as a root-owned regular mode `0755` file; register only its fixed service name and preserve literal operation arguments | Root authority or a compromised image builder can still replace trusted image state |
| Runtime state from a previous start satisfies readiness | Publish root-owned state atomically with PID and Linux process start time; `wait` and `status` reject malformed, stopped, stale or disappeared state | A forced kill can leave ephemeral files until the next entrypoint validates them |
| Root entrypoint gives broad service authority | Keep the entrypoint stable and project-owned; make service selection explicit in the Dockerfile; retain non-root `remoteUser` and use `wait` only as a read-only barrier | The root container process and privileged outer container remain broad trust boundaries |
| Graceful stop fails or an adapter hangs | Continue reverse shutdown after failures and leave timeouts to the outer runtime, which can force termination | A forced kill can leave a daemon or adapter abruptly terminated and no cleanup code can be guaranteed |
| Repository key substitution | Verify the downloaded primary fingerprint before creating the dedicated keyring | Compromise of Docker's signing infrastructure can still distribute trusted malicious packages |
| Conflicting repository or command state | Validate canonical files before package changes and fail rather than overwrite | A package operation can still fail after repository files are written |

## Qualification requirements

Qualification requires isolated installation tests, rejection of startup without the data mount, a privileged daemon lifecycle test using a non-`vfs` backend, proof that outer `--rm` deletes the anonymous volume, a nested container execution test and the complete project unit and integration suite using the installed daemon. When the adapter is registered, qualification additionally covers root entrypoint startup, non-root readiness and aggregate status, ordered rollback and reverse shutdown, signal forwarding and forced termination of a deliberately hanging adapter. Workflow-produced release `0.2.0` and its immutable OCI digest are available. The candidate Dev Container profile was independently built, passed the complete project suite through its installed daemon and replaced the public profile.
