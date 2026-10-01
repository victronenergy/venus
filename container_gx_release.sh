#!/usr/bin/env bash
# Publish the built OCI archives as one multi-architecture image under
# immutable version and channel tags.
#
# usage: ./container_gx_release.sh <beta|release>
set -euo pipefail

usage() {
    echo "Usage: $0 <beta|release>" >&2
    exit 1
}

[ "$#" -eq 1 ] || usage
CHANNEL="$1"

REPOS=(
    "ghcr.io/victronenergy/container-gx"
    "docker.io/victronenergy/container-gx"
)

MACHINES=(container-gx-amd64 container-gx-arm64 container-gx-armv7)

# releases move latest, the tag pulled when none is given
case "$CHANNEL" in
    beta) CHANNEL_TAG=beta ;;
    release) CHANNEL_TAG=latest ;;
    *) echo "ERROR: channel must be 'beta' or 'release', got '$CHANNEL'" >&2; exit 1 ;;
esac

for command in skopeo python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: $command not found on PATH" >&2
        exit 1
    fi
done

LAYOUT_DIR="$(mktemp -d)"
trap 'rm -rf "$LAYOUT_DIR"' EXIT
LAYOUT="${LAYOUT_DIR}/layout"

declare -A ARCHIVES
VERSION=""

for machine in "${MACHINES[@]}"; do
    deploy_images="deploy/venus/images/${machine}"
    shopt -s nullglob
    archives=("${deploy_images}"/venus-*-oci.tar)
    shopt -u nullglob
    if [ "${#archives[@]}" -ne 1 ]; then
        echo "ERROR: expected one OCI archive reference in $deploy_images" >&2
        exit 1
    fi

    artifact="${archives[0]##*/}"
    version="${artifact#venus-}"
    version="${version%-oci.tar}"
    if [ -n "$VERSION" ] && [ "$version" != "$VERSION" ]; then
        echo "ERROR: OCI archives do not have a common Venus version" >&2
        exit 1
    fi
    VERSION="$version"
    ARCHIVES["$machine"]="${archives[0]}"
done

case "$VERSION" in
    ""|*[!A-Za-z0-9_.-]*)
        echo "ERROR: version '$VERSION' is not a valid container tag" >&2
        exit 1
        ;;
esac

# collect the three architecture images in one OCI layout, sharing blobs
for machine in "${MACHINES[@]}"; do
    skopeo copy --quiet "oci-archive:${ARCHIVES[$machine]}" "oci:${LAYOUT}:${machine}"
done

# replace the per-architecture entries with one image index, as
# meta-virtualization's oci-multiarch class does
python3 - "$LAYOUT" <<'EOF'
import hashlib, json, os, sys

layout = sys.argv[1]

def blob(digest):
    with open(os.path.join(layout, "blobs", *digest.split(":")), "rb") as f:
        return json.load(f)

def add_blob(data):
    raw = json.dumps(data, indent=2).encode()
    digest = hashlib.sha256(raw).hexdigest()
    with open(os.path.join(layout, "blobs", "sha256", digest), "wb") as f:
        f.write(raw)
    return "sha256:" + digest, len(raw)

with open(os.path.join(layout, "index.json")) as f:
    entries = json.load(f)["manifests"]

manifests = []
for entry in entries:
    config = blob(blob(entry["digest"])["config"]["digest"])
    platform = {"architecture": config["architecture"], "os": config["os"]}
    if config.get("variant"):
        platform["variant"] = config["variant"]
    elif config["architecture"] == "arm":
        platform["variant"] = "v7"
    manifests.append({
        "mediaType": entry["mediaType"],
        "digest": entry["digest"],
        "size": entry["size"],
        "platform": platform,
    })

platforms = sorted((m["platform"]["architecture"], m["platform"].get("variant", ""))
                   for m in manifests)
if platforms != [("amd64", ""), ("arm", "v7"), ("arm64", "")]:
    sys.exit("ERROR: OCI archives contain %s, expected amd64, arm64 and arm/v7" % platforms)

digest, size = add_blob({
    "schemaVersion": 2,
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "manifests": manifests,
})
with open(os.path.join(layout, "index.json"), "w") as f:
    json.dump({
        "schemaVersion": 2,
        "manifests": [{
            "mediaType": "application/vnd.oci.image.index.v1+json",
            "digest": digest,
            "size": size,
            "annotations": {"org.opencontainers.image.ref.name": "multiarch"},
        }],
    }, f, indent=2)
EOF

verify_index() {
    local image="$1"

    skopeo inspect --raw "$image" | python3 -c '
import json, sys
index = json.load(sys.stdin)
platforms = sorted((m["platform"]["os"], m["platform"]["architecture"],
                    m["platform"].get("variant", ""))
                   for m in index.get("manifests", []))
expected = [("linux", "amd64", ""), ("linux", "arm", "v7"), ("linux", "arm64", "")]
sys.exit(0 if platforms == expected else 1)
' || {
        echo "ERROR: $image does not contain the expected platforms" >&2
        exit 1
    }
}

for repo in "${REPOS[@]}"; do
    immutable="docker://${repo}:${VERSION}"

    echo "Publishing $immutable"
    skopeo copy --all "oci:${LAYOUT}:multiarch" "$immutable"
    verify_index "$immutable"
done

for repo in "${REPOS[@]}"; do
    immutable="docker://${repo}:${VERSION}"
    channel="docker://${repo}:${CHANNEL_TAG}"

    echo "Advancing $channel from $immutable"
    skopeo copy --all "$immutable" "$channel"

    immutable_digest="$(skopeo inspect --format '{{.Digest}}' "$immutable")"
    channel_digest="$(skopeo inspect --format '{{.Digest}}' "$channel")"
    if [ "$immutable_digest" != "$channel_digest" ]; then
        echo "ERROR: $channel does not match $immutable" >&2
        exit 1
    fi
done

echo "Published $VERSION as $CHANNEL_TAG"
