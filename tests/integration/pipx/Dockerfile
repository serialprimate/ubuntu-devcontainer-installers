# syntax=docker/dockerfile:1
# check=error=true

# Installs and repeats the default pipx release from the packaged collection layout.
FROM ubuntu:26.04 AS default-idempotent-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Python prerequisite installer beneath the stable collection payload root.
COPY installers/apt-python /opt/ubuntu-devcontainer-installers/installers/apt-python

# Copies the pipx installer beside its explicit Python prerequisite.
COPY installers/pipx /opt/ubuntu-devcontainer-installers/installers/pipx

# Preserves the bundled-library relationship used by both installers.
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Composes Python and pipx, repeats the exact request and verifies canonical installed state.
RUN /opt/ubuntu-devcontainer-installers/installers/apt-python/install.sh --without-pip \
    && /opt/ubuntu-devcontainer-installers/installers/pipx/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/pipx/install.sh \
    && test "$(pipx --version)" = '1.16.6' \
    && test "$(readlink -- /usr/local/bin/pipx)" = '/usr/local/lib/pipx/bin/pipx' \
    && /usr/local/lib/pipx/bin/python -m pip --version | grep -Fq 'pip 26.2.1'

# Verifies explicit release-age disablement with an independently installed image state.
FROM ubuntu:26.04 AS release-age-disable-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Python prerequisite installer.
COPY installers/apt-python /workspace/installers/apt-python

# Copies the pipx installer beside its prerequisite.
COPY installers/pipx /workspace/installers/pipx

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs pipx through the explicit release-age bypass and verifies its exact version.
RUN /workspace/installers/apt-python/install.sh --without-pip \
    && /workspace/installers/pipx/install.sh --without-minimum-release-age \
    && test "$(pipx --version)" = '1.16.6'

# Reports the required installer composition order when Python is absent.
FROM ubuntu:26.04 AS prerequisite-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx installer and expected-failure helper.
COPY installers/pipx /workspace/installers/pipx

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Verifies the missing prerequisite identifies Python-first composition.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'Run installers/apt-python/install.sh before invoking pipx' \
    /workspace/installers/pipx/install.sh

# Rejects an existing canonical pipx installation at a different version.
FROM ubuntu:26.04 AS version-collision-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx installer and expected-failure helper.
COPY installers/pipx /workspace/installers/pipx

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Creates deterministic prerequisite and canonical existing-installation commands.
RUN mkdir -p -- /usr/local/lib/pipx/bin \
    && printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >/usr/local/bin/python3 \
    && printf '%s\n' '#!/usr/bin/env bash' 'printf "1.16.6\\n"' \
        >/usr/local/lib/pipx/bin/pipx \
    && chmod 0755 /usr/local/bin/python3 /usr/local/lib/pipx/bin/pipx \
    && ln -s -- /usr/local/lib/pipx/bin/pipx /usr/local/bin/pipx

# Proves another requested version cannot overwrite the existing single instance.
RUN /workspace/tests/lib/assert-command-fails.sh \
    2 'pipx 1.16.6 is already installed; remove it before requesting pipx 1.16.5' \
    /workspace/installers/pipx/install.sh --pipx-version 1.16.5

# Rejects unsupported release metadata before creating a virtual environment.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the pipx installer and expected-failure helper.
COPY installers/pipx /workspace/installers/pipx

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves platform validation precedes Python execution.
RUN printf 'ID=debian\nVERSION_ID="13"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/pipx/install.sh
