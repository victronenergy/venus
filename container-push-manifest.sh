#!/usr/bin/env bash
# Combines the three already-pushed per-machine channel images
# (<channel>-amd64 / -arm64 / -armv7, as container-push.sh tags them)
# into one real multi-arch OCI manifest, so a single tag resolves to
# the right platform automatically (docker/podman pull, and Home
# Assistant's own arch: list in venusos/config.yaml - see that file's
# comments).
#
# Also tags+pushes each per-machine image under Home Assistant's own
# arch vocabulary (amd64/aarch64/armv7, not amd64-oci/arm64-oci/
# armv7-oci) - the manifest is built from those, since our own machine
# names don't match HA's expected architecture names.
#
# usage: ./container-push-manifest.sh <beta|release>
set -euo pipefail

CHANNEL="${1:?usage: $0 <beta|release>}"
GHCR_REPO="${GHCR_REPO:-ghcr.io/nmbath/venusoci}"

case "$CHANNEL" in
    beta|release) ;;
    *) echo "ERROR: channel must be 'beta' or 'release', got '$CHANNEL'" >&2; exit 1 ;;
esac

declare -A HA_ARCH=( [amd64-oci]=amd64 [arm64-oci]=aarch64 [armv7-oci]=armv7 )

ALIAS_TAGS=()
for machine in amd64-oci arm64-oci armv7-oci; do
    ha_arch="${HA_ARCH[$machine]}"
    src="${GHCR_REPO}:${CHANNEL}-${machine%-oci}"
    alias="${GHCR_REPO}:${CHANNEL}-${ha_arch}"
    echo "Tagging $alias from $src"
    docker tag "$src" "$alias"
    docker push "$alias"
    ALIAS_TAGS+=("$alias")
done

echo "Creating multi-arch manifest ${GHCR_REPO}:${CHANNEL} from ${ALIAS_TAGS[*]}"
docker buildx imagetools create -t "${GHCR_REPO}:${CHANNEL}" "${ALIAS_TAGS[@]}"

echo "Done: ${GHCR_REPO}:${CHANNEL} (amd64/aarch64/armv7)"
