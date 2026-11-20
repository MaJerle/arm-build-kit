# Universal Cortex-M firmware build image:
#  - Arm GNU Toolchain (arm-none-eabi-gcc), pinned
#  - CMake, Ninja, Make, Git, clang-format/clang-tidy, cppcheck
#  - Python venv (uv-managed interpreter) with a minimal base set from pyproject.toml / uv.lock
#  - install-build-requirements: adds a project's requirements-build.txt on top
#  - This repo's CMake toolchain/CPU files under /opt/arm-build-kit/cmake
#
# Published as ghcr.io/majerle/arm-build-kit (linux/amd64 + linux/arm64).

FROM ubuntu:24.04

# Pinned ARM GNU Toolchain release (official upstream build)
# https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
ARG ARM_TOOLCHAIN_VERSION=15.2.rel1

# Set automatically by Docker Buildx (amd64/arm64) - picks the matching
# ARM-hosted tarball (x86_64/aarch64), so it runs natively on Apple Silicon too.
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    ninja-build \
    make \
    python3 \
    python3-pip \
    git \
    curl \
    xz-utils \
    ca-certificates \
    clang-format \
    clang-tidy \
    cppcheck \
    && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
    amd64) ARM_ARCH=x86_64 ;; \
    arm64) ARM_ARCH=aarch64 ;; \
    *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/arm-toolchain.tar.xz \
    "https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-${ARM_ARCH}-arm-none-eabi.tar.xz" && \
    mkdir -p /opt/arm-gnu-toolchain && \
    tar -xJf /tmp/arm-toolchain.tar.xz -C /opt/arm-gnu-toolchain --strip-components=1 && \
    rm /tmp/arm-toolchain.tar.xz

ENV PATH="/opt/arm-gnu-toolchain/bin:${PATH}"

# Python environment: uv installs the interpreter from .python-version and the
# locked dependencies into /opt/venv, which is put first on PATH.
RUN pip install --break-system-packages --no-cache-dir uv
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY pyproject.toml uv.lock .python-version /tmp/build-ctx/
RUN UV_PROJECT_ENVIRONMENT=/opt/venv uv sync --project /tmp/build-ctx --locked --no-install-project \
    && rm -rf /tmp/build-ctx /root/.cache/uv \
    && chmod -R a+rX /opt/uv-python \
    && chmod -R a+rwX /opt/venv

# Project-specific packages: requirements-build.txt in the working directory is
# installed by the entrypoint (docker run), or explicitly via
# `install-build-requirements` (CI container jobs, devcontainer postCreateCommand).
# /opt/venv is world-writable so this also works with `docker run --user <uid>`.
ENV ARM_BUILD_KIT_REQUIREMENTS=requirements-build.txt
ENV UV_CACHE_DIR=/tmp/uv-cache
ENV UV_LINK_MODE=copy
COPY docker/install-build-requirements /usr/local/bin/install-build-requirements
COPY docker/entrypoint.sh /usr/local/bin/arm-build-kit-entrypoint

# CMake toolchain + CPU flag files from this repo
COPY cmake/ /opt/arm-build-kit/cmake/
ENV ARM_BUILD_KIT_CMAKE_DIR=/opt/arm-build-kit/cmake

# No fixed WORKDIR: callers mount their project and pass -w at run time.
ENTRYPOINT ["/usr/local/bin/arm-build-kit-entrypoint"]
CMD ["bash"]
