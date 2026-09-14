#!/usr/bin/env bash
# Packages a venus-image-oci rootfs tarball into a real docker-built
# image and pushes it to GHCR. Docker only - podman-imported single-layer
# images trigger a Docker Desktop containerd-snapshotter bug on pull
# ("wrong diff id ..."); the registry data itself is fine (verified against
# the raw API), Desktop just miscomputes the digest on extraction. A real
# `docker build` (FROM scratch + ADD) doesn't hit it.
#
# usage: ./container-push.sh <machine> [beta|release]
#   beta/release also tags+pushes <channel>-<arch> alongside the version
#   tag (e.g. v3.80-46-arm64 and beta-arm64), <arch> being <machine> with
#   any trailing -oci stripped.
set -euo pipefail

MACHINE="${1:?usage: $0 <machine> [beta|release]}"
CHANNEL="${2:-}"
GHCR_REPO="${GHCR_REPO:-ghcr.io/nmbath/venusoci}"
DEPLOY_IMAGES="deploy/venus/images/${MACHINE}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found on PATH - required (see this script's header for why)" >&2
    exit 1
fi

case "$MACHINE" in
    amd64-oci) PLATFORM=linux/amd64 ;;
    arm64-oci) PLATFORM=linux/arm64 ;;
    armv7-oci) PLATFORM=linux/arm/v7 ;;
    *) echo "ERROR: unknown machine '$MACHINE'" >&2; exit 1 ;;
esac

case "$CHANNEL" in
    ""|beta|release) ;;
    *) echo "ERROR: channel must be 'beta' or 'release' (or omitted), got '$CHANNEL'" >&2; exit 1 ;;
esac

TARBALL="$(ls -t "${DEPLOY_IMAGES}"/venus-image-oci-"${MACHINE}"-[0-9]*.tar.bz2 2>/dev/null | head -1)"
if [ -z "$TARBALL" ]; then
    echo "ERROR: no venus-image-oci-${MACHINE}-<datetime>-<version>.tar.bz2 in $DEPLOY_IMAGES - build it first with 'make ${MACHINE}-oci'" >&2
    exit 1
fi

# venus-image-oci-<machine>-<14-digit-datetime>-<version>.tar.bz2
REAL_NAME="$(basename "$TARBALL")"
VERSION="${REAL_NAME#venus-image-oci-"${MACHINE}"-}"
VERSION="${VERSION#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}"
VERSION="${VERSION%.tar.bz2}"
case "$VERSION" in
    v[0-9]*) ;;
    *)
        echo "ERROR: couldn't parse a DISTRO_VERSION out of $REAL_NAME (got '$VERSION', expected something like v3.80 or v3.80~46)" >&2
        exit 1
        ;;
esac
VERSION_TAG="${VERSION//\~/-}"
TAG_ARCH="${MACHINE%-oci}"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
cp "$TARBALL" "$BUILD_DIR/rootfs.tar.bz2"
cat > "$BUILD_DIR/Dockerfile" <<'EOF'
FROM scratch
ADD rootfs.tar.bz2 /
ENTRYPOINT ["/sbin/init"]
EXPOSE 80 1883 8883 9001
VOLUME ["/data"]
EOF

VERSIONED_TAG="${GHCR_REPO}:${VERSION_TAG}-${TAG_ARCH}"
BUILD_TAGS=(-t "$VERSIONED_TAG")
if [ -n "$CHANNEL" ]; then
    CHANNEL_TAG="${GHCR_REPO}:${CHANNEL}-${TAG_ARCH}"
    BUILD_TAGS+=(-t "$CHANNEL_TAG")
fi

echo "Building $VERSIONED_TAG ($PLATFORM) from $TARBALL"
docker build --platform "$PLATFORM" "${BUILD_TAGS[@]}" "$BUILD_DIR"

docker push "$VERSIONED_TAG"
if [ -n "$CHANNEL" ]; then
    docker push "$CHANNEL_TAG"
fi

echo "Done: $VERSIONED_TAG${CHANNEL:+ and $CHANNEL_TAG}"
