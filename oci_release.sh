#!/usr/bin/env bash
# Publish built OCI archives under immutable version and channel tags.
#
# usage: ./oci_release.sh <amd64-oci|arm64-oci|armv7-oci|all> <beta|release>
set -euo pipefail

usage() {
    echo "Usage: $0 <amd64-oci|arm64-oci|armv7-oci|all> <beta|release>" >&2
    exit 1
}

[ "$#" -eq 2 ] || usage
MACHINE="$1"
CHANNEL="$2"

REPOS=(
    "ghcr.io/victronenergy/container-gx"
    "docker.io/victronenergy/container-gx"
)

case "$CHANNEL" in
    beta|release) ;;
    *) echo "ERROR: channel must be 'beta' or 'release', got '$CHANNEL'" >&2; exit 1 ;;
esac

case "$MACHINE" in
    all) MACHINES=(amd64 arm64 armv7) ;;
    amd64-oci|arm64-oci|armv7-oci) MACHINES=("${MACHINE%-oci}") ;;
    *) echo "ERROR: unknown machine '$MACHINE'" >&2; usage ;;
esac

if ! command -v skopeo >/dev/null 2>&1; then
    echo "ERROR: skopeo not found on PATH" >&2
    exit 1
fi

declare -A ARCHIVES
declare -A VERSIONS

for machine in "${MACHINES[@]}"; do
    deploy_images="deploy/venus/images/${machine}"
    shopt -s nullglob
    archives=("${deploy_images}"/venus-oci-*-oci.tar)
    shopt -u nullglob
    if [ "${#archives[@]}" -eq 0 ]; then
        echo "ERROR: no OCI archive found in $deploy_images" >&2
        exit 1
    fi
    if [ "${#archives[@]}" -ne 1 ]; then
        echo "ERROR: multiple OCI archive references found in $deploy_images" >&2
        exit 1
    fi

    archive="${archives[0]}"
    artifact="${archive##*/}"
    version="${artifact#venus-oci-}"
    version="${version%-oci.tar}"
    if [ -z "$version" ] || [ "$version" = "$artifact" ]; then
        echo "ERROR: cannot derive a version from $artifact" >&2
        exit 1
    fi

    case "$machine" in
        amd64) expected_arch=amd64 ;;
        arm64) expected_arch=arm64 ;;
        armv7) expected_arch=arm ;;
    esac
    actual_arch="$(skopeo inspect --format '{{.Architecture}}' "oci-archive:$archive")"
    if [ "$actual_arch" != "$expected_arch" ]; then
        echo "ERROR: $archive contains '$actual_arch', expected '$expected_arch'" >&2
        exit 1
    fi

    ARCHIVES["$machine"]="$archive"
    VERSIONS["$machine"]="$version"
done

release_version="${VERSIONS[${MACHINES[0]}]}"
for machine in "${MACHINES[@]}"; do
    if [ "${VERSIONS[$machine]}" != "$release_version" ]; then
        echo "ERROR: OCI archives do not have a common Venus version" >&2
        exit 1
    fi
done

for repo in "${REPOS[@]}"; do
    for machine in "${MACHINES[@]}"; do
        version_tag="${VERSIONS[$machine]}-${machine}"
        echo "Publishing ${repo}:${version_tag}"
        skopeo copy \
            "oci-archive:${ARCHIVES[$machine]}" \
            "docker://${repo}:${version_tag}"
    done
done

for repo in "${REPOS[@]}"; do
    for machine in "${MACHINES[@]}"; do
        version_tag="${VERSIONS[$machine]}-${machine}"
        channel_tag="${CHANNEL}-${machine}"
        echo "Advancing ${repo}:${channel_tag} from ${repo}:${version_tag}"
        skopeo copy \
            "docker://${repo}:${version_tag}" \
            "docker://${repo}:${channel_tag}"
    done
done

echo "Published ${release_version} for ${MACHINES[*]}"
