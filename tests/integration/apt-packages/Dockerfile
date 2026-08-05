# syntax=docker/dockerfile:1
# check=error=true

# Installs repeatable package sets from the preserved packaged-layout relationship.
FROM ubuntu:26.04 AS packaged-layout-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the installer beneath the stable collection payload root.
COPY installers/apt-packages /opt/ubuntu-devcontainer-installers/installers/apt-packages

# Preserves the bundled-library path resolved by the installer.
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Installs two sets independently and verifies commands and image-appropriate APT cleanup.
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
    && /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package xz-utils \
    && command -v update-ca-certificates >/dev/null \
    && command -v xz >/dev/null \
    && test ! -e /var/lib/apt/lists/lock \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Rejects invalid package input before any APT operation.
FROM ubuntu:26.04 AS invalid-input-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the source-tree installer.
COPY installers/apt-packages /workspace/installers/apt-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Proves option-like input is rejected with an actionable installer diagnostic.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'invalid package specification: --allow-unauthenticated' \
    /workspace/installers/apt-packages/install.sh --package --allow-unauthenticated

# Reports an actionable failure when APT cannot resolve a requested package.
FROM ubuntu:26.04 AS unavailable-package-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the source-tree installer.
COPY installers/apt-packages /workspace/installers/apt-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Verifies that a package-manager failure gains installer-qualified diagnostic advice.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'APT package installation failed; verify package names' \
    /workspace/installers/apt-packages/install.sh \
        --package ubuntu-devcontainer-installers-package-does-not-exist

# Rejects execution when the operating-system release contract does not match.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the source-tree installer.
COPY installers/apt-packages /workspace/installers/apt-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Substitutes unsupported release metadata and verifies fail-closed platform handling.
RUN printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/apt-packages/install.sh --package ca-certificates
