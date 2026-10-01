#!/usr/bin/env bash
# Publish immutable and channel multi-architecture manifests.
#
# usage: ./oci_manifest.sh <version> <beta|release>
set -euo pipefail

usage() {
    echo "Usage: $0 <version> <beta|release>" >&2
    exit 1
}

[ "$#" -eq 2 ] || usage
VERSION="$1"
CHANNEL="$2"

REPOS=(
    "ghcr.io/victronenergy/container-gx"
    "docker.io/victronenergy/container-gx"
)

case "$VERSION" in
    ""|*[!A-Za-z0-9_.-]*)
        echo "ERROR: version '$VERSION' is not a valid container tag" >&2
        exit 1
        ;;
esac

case "$CHANNEL" in
    beta|release) ;;
    *) echo "ERROR: channel must be 'beta' or 'release', got '$CHANNEL'" >&2; exit 1 ;;
esac

for command in docker jq skopeo; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: $command not found on PATH" >&2
        exit 1
    fi
done

verify_image() {
    local image="$1"
    local expected_arch="$2"
    local config

    config="$(skopeo inspect --config "docker://$image")"
    if ! jq -e --arg arch "$expected_arch" \
        '.os == "linux" and .architecture == $arch' <<< "$config" >/dev/null; then
        echo "ERROR: $image is not the expected linux/$expected_arch image" >&2
        exit 1
    fi
}

verify_manifest() {
    local image="$1"
    local manifest

    manifest="$(docker manifest inspect "$image")"
    if ! jq -e '
        ([.manifests[].platform |
            {os, architecture, variant: (.variant // "")}] |
            sort_by(.architecture, .variant))
        ==
        ([
            {os: "linux", architecture: "amd64", variant: ""},
            {os: "linux", architecture: "arm64", variant: ""},
            {os: "linux", architecture: "arm", variant: "v7"}
        ] | sort_by(.architecture, .variant))
    ' <<< "$manifest" >/dev/null; then
        echo "ERROR: $image does not contain the expected platforms" >&2
        exit 1
    fi
}

for repo in "${REPOS[@]}"; do
    verify_image "${repo}:${VERSION}-amd64" amd64
    verify_image "${repo}:${VERSION}-arm64" arm64
    verify_image "${repo}:${VERSION}-armv7" arm
done

for repo in "${REPOS[@]}"; do
    target="${repo}:${VERSION}"

    docker manifest rm "$target" >/dev/null 2>&1 || :
    docker manifest create "$target" \
        "${repo}:${VERSION}-amd64" \
        "${repo}:${VERSION}-arm64" \
        "${repo}:${VERSION}-armv7"
    docker manifest annotate "$target" "${repo}:${VERSION}-armv7" \
        --os linux --arch arm --variant v7
    docker manifest push "$target"

    verify_manifest "$target"
done

for repo in "${REPOS[@]}"; do
    immutable="docker://${repo}:${VERSION}"
    channel="docker://${repo}:${CHANNEL}"

    echo "Advancing $channel from $immutable"
    skopeo copy --all "$immutable" "$channel"

    immutable_digest="$(skopeo inspect --format '{{.Digest}}' "$immutable")"
    channel_digest="$(skopeo inspect --format '{{.Digest}}' "$channel")"
    if [ "$immutable_digest" != "$channel_digest" ]; then
        echo "ERROR: $channel does not match $immutable" >&2
        exit 1
    fi
done
