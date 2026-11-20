#!/usr/bin/env bash
# Image entrypoint for `docker run`: installs requirements-build.txt from the
# working directory (if present), then runs the given command.
#
# Note: GitHub Actions `container:` jobs and dev containers bypass the entrypoint -
# call `install-build-requirements` explicitly there (step / postCreateCommand).
set -euo pipefail

install-build-requirements

exec "$@"
