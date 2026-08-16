# Docker-in-Docker installer

## Purpose

Installs Docker Engine, its CLI plugins and explicit lifecycle control for expert developers running container integration tests inside a development container. It also installs the optional `docker-in-docker` service adapter for [`container-services`](../container-services/README.md).

This design avoids automatic daemon startup and host-persistent named volumes. Docker state uses an anonymous outer-Docker volume so the nested daemon retains its copy-on-write storage backend without overlay-on-overlay mounts. The required outer `--rm` lifecycle removes that volume with the development container.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. Installation and `start` and `stop` lifecycle operations require `root`; `status` is readable by the development user.

The development container must run with `--privileged` for the nested daemon. Privileged containers can control kernel facilities and can compromise the host if the container runtime or kernel isolation fails. Use this installer only in disposable, trusted development environments; never expose its unauthenticated Unix socket outside the development container.

## Prerequisites

`apt-get`, `cmp`, `dpkg-query`, `install`, `mktemp`, `mountpoint`, `stat` and `gpg` must be available. The Ubuntu packages `ca-certificates`, `curl` and `gnupg` must already be installed. Install them explicitly with [`apt-packages`](../apt-packages/README.md) before invoking this installer.

No host Docker socket may be mounted at `/var/run/docker.sock`. At runtime, the development container must be privileged, use `--rm` and mount an anonymous volume at `/var/lib/docker-in-docker`. The development user must be a member of the inner `docker` group to use non-root `status`, `docker info` or `container-services wait`. Daemon startup fails when the dedicated data mount is absent. The installer does not infer privileges, create an outer-Docker volume or start a daemon during image construction.

## Usage

```text
install.sh
```

After the privileged development container starts, direct manual control remains available whether or not `container-services` is installed or registered:

```bash
sudo docker-in-docker start
docker-in-docker status
sudo docker-in-docker stop
```

The `sudo` examples describe an elevation choice, not a requirement for unrestricted passwordless sudo. A root terminal, interactive sudo or a narrowly reviewed command-specific policy may be used instead.

## Options

The installer accepts only `--help`, which prints help without changing system state. The installed manual command accepts exactly one of `start`, `stop`, `status` or `--help`; invalid arity and commands return status `2`.

The service adapter accepts one literal `start`, `stop` or `status` operation and delegates it to `/usr/local/sbin/docker-in-docker`. Its fixed service name is `docker-in-docker`, and its exact path is `/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker`.

`start` returns zero only after `docker info` proves functional readiness. `status` returns zero only when the managed process identity and Docker API are both valid. Repeated `start` fails for a managed live daemon; repeated `stop` reports that no managed daemon is running; stopped `status` returns non-zero.

## Installed files and commands

- `/usr/bin/docker` and `/usr/bin/dockerd` are supplied by Docker's packages.
- `/usr/libexec/docker/cli-plugins/docker-buildx` and `docker-compose` provide `docker buildx` and `docker compose`.
- `/etc/apt/keyrings/docker.gpg` contains the verified Docker repository signing key.
- `/etc/apt/sources.list.d/docker.sources` selects Docker's Ubuntu 26.04 `resolute` stable repository.
- `/usr/local/sbin/docker-in-docker` explicitly manages the nested daemon and is mode `0755`.
- `/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker` is the root-owned mode `0755` provider adapter.
- `/usr/local/libexec/ubuntu-devcontainer-installers/docker-in-docker/common.sh` is the root-owned mode `0644` private runtime logger.
- `/var/lib/docker-in-docker` is the daemon data root and required anonymous-volume mount point.
- `/run/docker-in-docker/dockerd.log` records daemon startup and runtime diagnostics.
- `/var/run/docker.sock` is the local, unauthenticated Unix socket owned by `root:docker`.

The installer installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin` without recommended packages. It does not create a volume during image construction, create a named volume, start `dockerd` or configure a TCP listener. The outer runtime creates the anonymous volume, and `--rm` removes it automatically with the container.

## Repeated invocation

**Single-instance and idempotent.** Repeating installation retains canonical repository, package, lifecycle, adapter and private-library state. A non-canonical Docker source or different root-owned runtime file is a collision and is not overwritten. Installation never registers the adapter or starts Docker.

Manual control and automatic control must not be mixed concurrently. The lifecycle command verifies its managed PID, command-line data root, PID file and Docker API. It removes only stale installer-owned PID state and an unmounted, nonresponsive socket; a mounted or live unmanaged socket is rejected. A registration manifest is owned by `container-services`, so removing registration or stopping the orchestrator does not change this installer’s manual command.

## Network sources and integrity

The installer uses `https://download.docker.com/linux/ubuntu` and its mutable `resolute/stable` package index. APT verifies repository metadata and packages with a dedicated `Signed-By` keyring.

The signing key is downloaded over HTTPS from `https://download.docker.com/linux/ubuntu/gpg`. Before installation, its full primary fingerprint must equal `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`; a mismatch fails closed. The installer does not use a controlled-risk network fallback.

## Examples

Install explicit prerequisites, Docker-in-Docker and `container-services`, then register the adapter in one layer:

```dockerfile
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

ENTRYPOINT ["container-services", "entrypoint", "--"]
```

Run the resulting development container with only the required broad runtime privilege and anonymous volume:

```bash
docker run --rm --privileged \
    --mount type=volume,destination=/var/lib/docker-in-docker \
    -it development-image
```

## Known limitations

Docker-in-Docker necessarily requires broad runtime privilege; Linux capabilities cannot safely express all nested daemon requirements. The data root is not configurable because host-persistent state is outside this milestone and nested overlay-on-overlay filesystems are not reliable. The anonymous volume consumes outer-Docker storage while the development container exists. Docker removes it automatically only because the required outer container uses `--rm`; interrupted tooling that leaves the container present also leaves its attached volume until that container is removed with volumes.

The command does not run as PID 1, supervise automatic restart or integrate with systemd. The adapter and orchestrator add no timeout beyond the daemon's existing 60-second readiness and shutdown checks. An outer runtime may forcibly terminate a deliberately hanging service adapter after its own stop timeout; forced termination can leave stale ephemeral state, which the next invocation validates rather than trusting.
