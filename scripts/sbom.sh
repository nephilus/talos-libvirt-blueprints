#!/usr/bin/env bash
set -euxo pipefail

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed." >&2
    exit 2
fi

usage() {
    echo "Usage: $0 <software_name> <version> <sbom_file>"
    exit 1
}

# Ensure correct usage
if [[ $# -ne 3 ]]; then
    usage
fi

SOFTWARE_NAME="$1"
SOFTWARE_VERSION="$2"
SBOM_FILE="$3"

# Create an empty SBOM file if it doesn't exist
if [[ ! -f "$SBOM_FILE" ]]; then
    echo '{"software": []}' > "$SBOM_FILE"
fi

update_sbom() {
    jq -c --arg name "$SOFTWARE_NAME" --arg version "$SOFTWARE_VERSION" '
        .software |= (map(select(.name != $name)) + [{"name": $name, "version": $version}])
    ' "$SBOM_FILE" > "$SBOM_FILE.tmp" && mv "$SBOM_FILE.tmp" "$SBOM_FILE"
}

update_sbom

echo "SBOM file '$SBOM_FILE' updated successfully."