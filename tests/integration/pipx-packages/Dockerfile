# syntax=docker/dockerfile:1
# check=error=true

# Installs multiple global application sets after composing Python and pipx.
FROM ubuntu:26.04 AS multiple-package-sets-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Python prerequisite installer beneath the stable collection payload root.
COPY installers/apt-python /opt/ubuntu-devcontainer-installers/installers/apt-python

# Copies the pipx installer beside its Python prerequisite.
COPY installers/pipx /opt/ubuntu-devcontainer-installers/installers/pipx

# Copies the pipx package installer beside its pipx prerequisite.
COPY installers/pipx-packages /opt/ubuntu-devcontainer-installers/installers/pipx-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /opt/ubuntu-devcontainer-installers/tests/lib/assert-command-fails.sh

# Preserves the bundled-library relationship used by every installer.
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Composes prerequisites and exercises repeatable values, cooldowns and independent package sets.
RUN /opt/ubuntu-devcontainer-installers/installers/apt-python/install.sh --without-pip \
    && /opt/ubuntu-devcontainer-installers/installers/pipx/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/pipx-packages/install.sh \
        --package pycowsay==0.0.0.2 \
        --package isort==5.13.2 \
    && /opt/ubuntu-devcontainer-installers/installers/pipx-packages/install.sh \
        --package cowsay==6.1 \
        --cooldown-days 30 \
    && pipx list --global --short | grep -Fq 'pycowsay 0.0.0.2' \
    && pipx list --global --short | grep -Fq 'isort 5.13.2' \
    && pipx list --global --short | grep -Fq 'cowsay 6.1' \
    && pycowsay 'Ubuntu 26.04' >/dev/null \
    && isort --version-number | grep -Fxq '5.13.2' \
    && cowsay --version >/dev/null \
    && /opt/ubuntu-devcontainer-installers/installers/pipx-packages/install.sh \
        --package pycowsay==0.0.0.2 \
    && /opt/ubuntu-devcontainer-installers/tests/lib/assert-command-fails.sh \
        1 'pycowsay 0.0.0.2 is already installed; remove or upgrade it before requesting 0.0.0.1' \
        /opt/ubuntu-devcontainer-installers/installers/pipx-packages/install.sh \
        --package pycowsay==0.0.0.1

# Verifies explicit cooldown disablement and literal package arguments with a recording pipx.
FROM ubuntu:26.04 AS cooldown-disable-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx package installer.
COPY installers/pipx-packages /workspace/installers/pipx-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs a deterministic recording pipx command for argument inspection.
RUN printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "${1:-}" == "--version" ]]; then printf "1.16.6\\n"; exit; fi' \
        'printf "%s\\n" "$@" >/tmp/pipx-arguments' \
        >/usr/local/bin/pipx \
    && chmod 0755 /usr/local/bin/pipx

# Proves explicit disablement omits only cooldown and preserves one literal package value.
RUN /workspace/installers/pipx-packages/install.sh \
        --package Example.Tool==1.0+local \
        --without-cooldown \
    && grep -Fxq -- 'install' /tmp/pipx-arguments \
    && grep -Fxq -- '--global' /tmp/pipx-arguments \
    && grep -Fxq -- 'Example.Tool==1.0+local' /tmp/pipx-arguments \
    && ! grep -Fq -- '--cooldown=' /tmp/pipx-arguments

# Reports the required installer composition order when pipx is absent.
FROM ubuntu:26.04 AS prerequisite-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx package installer and expected-failure helper.
COPY installers/pipx-packages /workspace/installers/pipx-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Verifies the missing prerequisite identifies pipx-first composition.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'Run installers/pipx/install.sh before invoking pipx-packages' \
    /workspace/installers/pipx-packages/install.sh --package pycowsay==0.0.0.2

# Rejects pipx versions that cannot enforce the default cooldown.
FROM ubuntu:26.04 AS unsupported-pipx-version-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx package installer and expected-failure helper.
COPY installers/pipx-packages /workspace/installers/pipx-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Provides an old pipx version without implementing an installation operation.
RUN printf '%s\n' '#!/usr/bin/env bash' 'printf "1.15.0\\n"' >/usr/local/bin/pipx \
    && chmod 0755 /usr/local/bin/pipx

# Proves the requested default control fails clearly rather than being silently omitted.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'package cooldown requires pipx 1.16.0 or newer; found 1.15.0' \
    /workspace/installers/pipx-packages/install.sh --package pycowsay==0.0.0.2

# Rejects unsupported release metadata before invoking an available pipx command.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx package installer and expected-failure helper.
COPY installers/pipx-packages /workspace/installers/pipx-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves platform validation precedes pipx execution.
RUN printf 'ID=debian\nVERSION_ID="13"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/pipx-packages/install.sh --package pycowsay==0.0.0.2
