#!/bin/zsh

# Check if ns-cli has an available upgrade
# If a newer version is available, touch ~/.northslope/ns-upgrade-available

NORTHSLOPE_DIR=${HOME}/.northslope
UPGRADE_AVAILABLE_FILE=${NORTHSLOPE_DIR}/ns-upgrade-available

# Ensure the northslope directory exists
mkdir -p "${NORTHSLOPE_DIR}" > /dev/null 2>&1

# Function to get the latest version from npm
get_latest_npm_version() {
    npm view @northslopetech/ns-cli version 2>/dev/null
}

# Function to get the local installed version
get_local_ns_version() {
    ns -V 2>/dev/null | tr -d 'v'
}

# Function to compare versions (returns 0 if v1 < v2, 1 otherwise)
version_less_than() {
    local v1=$1
    local v2=$2

    # Use sort -V for semantic version comparison
    # If v1 appears first when sorted, it means v1 < v2
    [ "$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1)" = "$v1" ] && [ "$v1" != "$v2" ]
}

# Get versions
latest_version=$(get_latest_npm_version)
local_version=$(get_local_ns_version)

# Check if we successfully got both versions
if [[ -z "${latest_version}" ]]; then
    echo "Warning: Could not fetch latest version from npm" >&2
    exit 1
fi

if [[ -z "${local_version}" ]]; then
    echo "Warning: Could not get local ns version (is ns-cli installed?)" >&2
    exit 1
fi

# Compare versions
if version_less_than "${local_version}" "${latest_version}"; then
    echo "Upgrade available: ${local_version} -> ${latest_version}"
    touch "${UPGRADE_AVAILABLE_FILE}"
    exit 0
else
    echo "ns-cli is up to date (${local_version})"
    # Remove the upgrade file if it exists
    rm -f "${UPGRADE_AVAILABLE_FILE}" > /dev/null 2>&1
    exit 0
fi
