# syntax=docker/dockerfile:1
# check=error=true

ARG VERSION
ARG REVISION
ARG CREATED

# Packages the non-runtime installer collection in its stable repository-relative layout
FROM scratch

ARG VERSION
ARG REVISION
ARG CREATED

LABEL org.opencontainers.image.title="Ubuntu Devcontainer Installers" \
    org.opencontainers.image.description="Reusable Ubuntu 26.04 development-container installers" \
    org.opencontainers.image.source="https://github.com/serialprimate/ubuntu-devcontainer-installers" \
    org.opencontainers.image.url="https://github.com/serialprimate/ubuntu-devcontainer-installers" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.revision="${REVISION}" \
    org.opencontainers.image.created="${CREATED}"

# Copies installer entry points and their documentation into the stable payload root
COPY installers /ubuntu-devcontainer-installers/installers

# Preserves the repository-relative path used for bundled-library resolution
COPY lib /ubuntu-devcontainer-installers/lib

# Includes collection-level legal and usage documentation
COPY LICENSE README.md /ubuntu-devcontainer-installers/
