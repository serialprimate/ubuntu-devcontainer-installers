# syntax=docker/dockerfile:1
# check=error=true

# Installs and repeats the default LTS release from the packaged collection layout.
FROM ubuntu:26.04 AS packaged-lts-idempotent-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the prerequisite installer beneath the stable collection payload root.
COPY installers/apt-packages /opt/ubuntu-devcontainer-installers/installers/apt-packages

# Copies the Node.js installer beside its explicit prerequisite installer.
COPY installers/node /opt/ubuntu-devcontainer-installers/installers/node

# Preserves the bundled-library path resolved by both installers.
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Installs explicit prerequisites before verifying Node.js and signed repository state.
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh --node-version 24 \
    && test "$(node --version | cut -d. -f1)" = 'v24' \
    && npm --version \
    && grep -Fxq 'URIs: https://deb.nodesource.com/node_24.x' \
        /etc/apt/sources.list.d/nodesource.sources \
    && grep -Fxq 'Signed-By: /usr/share/keyrings/nodesource.gpg' \
        /etc/apt/sources.list.d/nodesource.sources \
    && test "$(stat -c '%a' /usr/share/keyrings/nodesource.gpg)" = '644' \
    && test "$(stat -c '%a' /etc/apt/sources.list.d/nodesource.sources)" = '644' \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Installs the explicitly selected Current major in an independent fresh image.
FROM ubuntu:26.04 AS current-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the prerequisite installer into the source-tree layout.
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the Node.js installer beside its explicit prerequisite installer.
COPY installers/node /workspace/installers/node

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs explicit prerequisites and verifies Current resolves to Node.js 26.
RUN /workspace/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /workspace/installers/node/install.sh --node-version current \
    && test "$(node --version | cut -d. -f1)" = 'v26' \
    && grep -Fxq 'URIs: https://deb.nodesource.com/node_26.x' \
        /etc/apt/sources.list.d/nodesource.sources \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Rejects missing repository-bootstrap dependencies without installing them implicitly.
FROM ubuntu:26.04 AS prerequisite-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Node.js installer.
COPY installers/node /workspace/installers/node

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Proves the failure identifies the explicit prerequisite composition command.
RUN /workspace/tests/lib/assert-command-fails.sh \
        1 'Run installers/apt-packages/install.sh' \
        /workspace/installers/node/install.sh \
    && test "$(dpkg-query --show --showformat='${db:Status-Abbrev}' \
        ca-certificates 2>/dev/null || true)" != 'ii ' \
    && test ! -e /etc/apt/sources.list.d/nodesource.sources \
    && test ! -e /usr/share/keyrings/nodesource.gpg

# Rejects a different major after an initial installation without replacing repository state.
FROM ubuntu:26.04 AS major-collision-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the prerequisite installer into the source-tree layout.
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the Node.js installer beside its explicit prerequisite installer.
COPY installers/node /workspace/installers/node

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs prerequisites and proves a conflicting major leaves repository state unchanged.
RUN /workspace/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /workspace/installers/node/install.sh --node-version 24 \
    && sha256sum /etc/apt/sources.list.d/nodesource.sources >/tmp/source.sha256 \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'Node.js 24 is already installed; remove it before requesting Node.js 26' \
        /workspace/installers/node/install.sh --node-version 26 \
    && sha256sum --check /tmp/source.sha256

# Rejects execution when release metadata does not identify Ubuntu 26.04.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the Node.js installer.
COPY installers/node /workspace/installers/node

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves platform validation precedes APT operations.
RUN printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/node/install.sh
