#!/usr/bin/env bash
# Convert a built OCI archive into an archive that docker load accepts.
#
# usage: ./container_gx_loadable.sh <amd64-container-gx|arm64-container-gx|armv7-container-gx>
set -euo pipefail

usage() {
    echo "Usage: $0 <amd64-container-gx|arm64-container-gx|armv7-container-gx>" >&2
    exit 1
}

[ "$#" -eq 1 ] || usage
TARGET="$1"

case "$TARGET" in
    amd64-container-gx|arm64-container-gx|armv7-container-gx) ARCH="${TARGET%-container-gx}"; MACHINE="container-gx-${ARCH}" ;;
    *) echo "ERROR: unknown target '$TARGET'" >&2; usage ;;
esac

if ! command -v skopeo >/dev/null 2>&1; then
    echo "ERROR: skopeo not found on PATH" >&2
    exit 1
fi

DEPLOY_IMAGES="deploy/venus/images/${MACHINE}"
shopt -s nullglob
archives=("${DEPLOY_IMAGES}"/venus-*-oci.tar)
shopt -u nullglob
if [ "${#archives[@]}" -ne 1 ]; then
    echo "ERROR: expected one OCI archive reference in $DEPLOY_IMAGES" >&2
    exit 1
fi

link="${archives[0]##*/}"
version="${link#venus-}"
version="${version%-oci.tar}"

# the link points to venus-<machine>-<datetime>-<version>-oci-<version>-...
archive="$(readlink "${archives[0]}")"
build="${archive%-oci-"${version}"-*}"
if [ "$build" = "$archive" ]; then
    echo "ERROR: cannot derive the build from $archive" >&2
    exit 1
fi

LOADABLE="${DEPLOY_IMAGES}/${build}-loadable.tar"
LOADABLE_LINK="${DEPLOY_IMAGES}/venus-${MACHINE}-loadable.tar"

# bitbake removes the previous build's images, so remove its archives too
rm -f "${DEPLOY_IMAGES}/venus-${MACHINE}"-*-loadable.tar
skopeo copy --quiet \
    "oci-archive:${DEPLOY_IMAGES}/${archive}" \
    "docker-archive:${LOADABLE}:container-gx:${ARCH}-${version}"
ln -sfn "${LOADABLE##*/}" "$LOADABLE_LINK"

echo "Created $LOADABLE"
