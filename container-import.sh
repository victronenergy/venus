#!/usr/bin/env bash
# Imports a venus-image-oci rootfs tarball into the local docker image
# store, tagged venus-image-oci:<arch> and :<arch>-<version>, where <arch>
# is <machine> with any trailing -oci stripped (e.g. arm64-oci -> arm64).
# See container-push.sh to publish the version-tagged image to a registry.
#
# usage: ./container-import.sh <machine>
set -euo pipefail

MACHINE="${1:?usage: $0 <machine>}"
DEPLOY_IMAGES="deploy/venus/images/${MACHINE}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found on PATH" >&2
    exit 1
fi

# rootfs tarball has no platform metadata of its own - without telling the
# runtime what's actually inside, import stamps the *host's* arch, so e.g.
# an amd64-oci image built on an aarch64 build server silently gets tagged
# linux/arm64 and then fails at "docker run" with "exec format error".
case "$MACHINE" in
    amd64-oci) OS=linux; ARCH=amd64; VARIANT= ;;
    arm64-oci) OS=linux; ARCH=arm64; VARIANT= ;;
    armv7-oci) OS=linux; ARCH=arm; VARIANT=v7 ;;
    *) echo "ERROR: unknown machine '$MACHINE'" >&2; exit 1 ;;
esac

if [ ! -d "$DEPLOY_IMAGES" ]; then
    echo "ERROR: $DEPLOY_IMAGES not found - build it first with 'make ${MACHINE}-oci'" >&2
    exit 1
fi

ROOTFS_TARBALL="${DEPLOY_IMAGES}/venus-image-oci-${MACHINE}.tar.bz2"
if [ ! -e "$ROOTFS_TARBALL" ]; then
    echo "ERROR: $ROOTFS_TARBALL not found - build it first with 'make ${MACHINE}-oci'" >&2
    exit 1
fi

# venus-image-oci-<machine>-<14-digit-datetime>-<version>.tar.bz2
REAL_TARBALL="$(readlink -f "$ROOTFS_TARBALL" 2>/dev/null || greadlink -f "$ROOTFS_TARBALL")"
REAL_NAME="$(basename "$REAL_TARBALL")"
VERSION="${REAL_NAME#venus-image-oci-"${MACHINE}"-}"
VERSION="${VERSION#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}"
VERSION="${VERSION%.tar.bz2}"
if [ -z "$VERSION" ] || [ "$VERSION" = "$REAL_NAME" ]; then
    echo "ERROR: couldn't parse a DISTRO_VERSION out of $REAL_NAME" >&2
    exit 1
fi
VERSION_TAG="${VERSION//\~/-}"
TAG_ARCH="${MACHINE%-oci}"

echo "Importing $ROOTFS_TARBALL into docker as venus-image-oci:${TAG_ARCH} (version ${VERSION} -> tag ${VERSION_TAG})"
docker import \
    --platform "${OS}/${ARCH}${VARIANT:+/$VARIANT}" \
    --change 'ENTRYPOINT ["/sbin/init"]' \
    --change 'EXPOSE 80' \
    --change 'EXPOSE 1883' \
    --change 'EXPOSE 8883' \
    --change 'EXPOSE 9001' \
    --change 'VOLUME ["/data"]' \
    "$ROOTFS_TARBALL" "venus-image-oci:${TAG_ARCH}"

docker tag "venus-image-oci:${TAG_ARCH}" "venus-image-oci:${TAG_ARCH}-${VERSION_TAG}"

IMAGE_OUT="${DEPLOY_IMAGES}/venus-image-oci-${MACHINE}.tar.gz"
rm -f "$IMAGE_OUT"
echo "Saving venus-image-oci:${TAG_ARCH} to $IMAGE_OUT"
docker save "venus-image-oci:${TAG_ARCH}" | gzip > "$IMAGE_OUT"

echo "Done: venus-image-oci:${TAG_ARCH} and venus-image-oci:${TAG_ARCH}-${VERSION_TAG} (local image + $IMAGE_OUT)"
