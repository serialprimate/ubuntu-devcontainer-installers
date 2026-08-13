# Docker-in-Docker installer

## Purpose

Installs Docker Engine, its CLI plugins and an explicit daemon lifecycle command for expert developers running container integration tests inside a development container.

This design deliberately avoids automatic daemon startup and host-persistent named volumes. Docker state uses an anonymous outer-Docker volume so the nested daemon retains its copy-on-write storage backend without overlay-on-overlay mounts. The required outer `--rm` lifecycle removes that volume with the development container.

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`. Installation and daemon lifecycle management require `root`.

The development container must run with `--privileged` for the nested daemon. Privileged containers can control kernel facilities and can compromise the host if the container runtime or kernel isolation fails. Use this installer only in disposable, trusted development environments; never expose its unauthenticated Unix socket outside the development container.

## Prerequisites

`apt-get`, `cmp`, `dpkg-query` and `mountpoint` must be available. The Ubuntu packages `ca-certificates`, `curl` and `gnupg` must already be installed. Install them explicitly with [`apt-packages`](../apt-packages/README.md) before invoking this installer.

No host Docker socket may be mounted at `/var/run/docker.sock`. At runtime, the development container must be privileged, use `--rm` and mount an anonymous volume at `/var/lib/docker-in-docker`. Daemon startup fails when the dedicated data mount is absent. The installer does not infer privileges, create an outer-Docker volume or start a daemon during the image build.

## Usage

```text
install.sh
```

After the privileged development container starts, explicitly start and stop its daemon:

```bash
sudo docker-in-docker start
docker info
sudo docker-in-docker stop
```

## Options

- `--help`: prints help and exits without changing system state.

The installed `docker-in-docker` command accepts exactly one of `start`, `stop`, `status` or `--help`.

## Installed files and commands

- `/usr/bin/docker` and `/usr/bin/dockerd` are supplied by Docker's packages.
- `/usr/libexec/docker/cli-plugins/docker-buildx` and `docker-compose` provide `docker buildx` and `docker compose`.
- `/etc/apt/keyrings/docker.gpg` contains the verified Docker repository signing key.
- `/etc/apt/sources.list.d/docker.sources` selects Docker's Ubuntu 26.04 `resolute` stable repository.
- `/usr/local/sbin/docker-in-docker` explicitly manages the nested daemon.
- `/var/lib/docker-in-docker` is the daemon data root and required anonymous-volume mount point.
- The storage backend is Docker's supported default for the volume's backing filesystem, not `vfs`.
- `/run/docker-in-docker/dockerd.log` records daemon startup and runtime diagnostics.
- `/var/run/docker.sock` is the local, unauthenticated Unix socket owned by `root:docker`.

The installer installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin` without recommended packages. It does not create a volume during image construction, create a named volume, start `dockerd` or configure a TCP listener. The outer runtime creates the anonymous volume, and `--rm` removes it automatically with the container.

## Repeated invocation

**Single-instance and idempotent.** Repeating installation refreshes the canonical repository and packages and reinstalls the same lifecycle command. A non-canonical Docker source or different file at `/usr/local/sbin/docker-in-docker` is a collision and is not overwritten.

`docker-in-docker start` fails if its managed daemon is already running or `/var/run/docker.sock` already exists. `stop` affects only the PID recorded by the managed daemon and verifies that PID still identifies `dockerd`.

## Network sources and integrity

The installer uses `https://download.docker.com/linux/ubuntu` and its mutable `resolute/stable` package index. APT verifies repository metadata and packages with a dedicated `Signed-By` keyring.

The signing key is downloaded over HTTPS from `https://download.docker.com/linux/ubuntu/gpg`. Before installation, its full primary fingerprint must equal `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`; a mismatch fails closed.

## Examples

Install explicit prerequisites and Docker-in-Docker while building an image:

```bash
../apt-packages/install.sh \
    --package ca-certificates \
    --package curl \
    --package gnupg
./install.sh
```

Run the resulting development container with only the required broad runtime privilege, then manage the daemon explicitly:

```bash
docker run --rm --privileged \
    --mount type=volume,destination=/var/lib/docker-in-docker \
    -it development-image
sudo docker-in-docker start
docker info
sudo docker-in-docker stop
```

## Known limitations

Docker-in-Docker necessarily requires broad runtime privilege; Linux capabilities cannot safely express all nested daemon requirements. The data root is not configurable because host-persistent state is outside this milestone and nested overlay-on-overlay filesystems are not reliable. The anonymous volume consumes outer-Docker storage while the development container exists. Docker removes it automatically only because the required outer container uses `--rm`; interrupted tooling that leaves the container present also leaves its attached volume until that container is removed with volumes.

The command does not run as PID 1, supervise automatic restart or integrate with systemd. Startup and shutdown are intentional lifecycle operations. Abruptly stopping the development container may prevent graceful daemon shutdown, but its state remains scoped to that container.
