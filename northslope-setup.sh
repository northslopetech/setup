#!/bin/zsh

NORTHSLOPE_DIR=${HOME}/.northslope
NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH=${NORTHSLOPE_DIR}/setup-version
mkdir -p ${NORTHSLOPE_DIR} > /dev/null 2>&1
NORTHSLOPE_SETUP_SCRIPT_PATH=${NORTHSLOPE_DIR}/setup.sh
NORTHSLOPE_NORTHSLOPE_SETUP_SCRIPT_PATH=${NORTHSLOPE_DIR}/northslope-setup.sh

# PostHog configuration for error tracking
POSTHOG_KEY=phc_Me99GOmroO6r5TiJwJoD3VpSoBr6JbWk3lo9rrLkEyQ
session_key="$(date +%s)-$(( ( $RANDOM % 100 ) + 1 ))"
current_timezone=$(date "+%z")

function get_timestamp {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

function emit_wrapper_failure_event {
    local error_msg=$1
    local exit_code=${2:-1}
    local timestamp=$(get_timestamp)
    local local_version=$(get_local_version)
    local remote_version=$(get_latest_version)

    # Escape error message for JSON (backslashes first, then quotes, then newlines)
    local escaped_error_msg=$(printf '%s' "${error_msg}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{if(NR>1)printf "\\n"; printf "%s", $0}' | tr -d '\r')

    # Build exception list
    local exception_list="[{\"type\":\"northslope-setup:failure\",\"value\":\"${escaped_error_msg}\",\"mechanism\":{\"type\":\"shell_script\",\"handled\":false},\"module\":\"northslope-setup.sh\"}]"

    curl --silent -XPOST https://us.i.posthog.com/capture/ \
        --header "Content-Type: application/json" \
        --data '{
            "api_key": "'"${POSTHOG_KEY}"'",
            "event": "$exception",
            "properties": {
                "distinct_id": "'"${USER}"'",
                "user": "'"${USER}"'",
                "timestamp": "'"${timestamp}"'",
                "$exception_type": "northslope-setup:failure",
                "$exception_message": "'"${escaped_error_msg}"'",
                "$exception_level": "error",
                "$exception_list": '"${exception_list}"',
                "$exception_fingerprint": "northslope-setup-failure-'"${session_key}"'",
                "exit_code": '"${exit_code}"',
                "local_version": "'"${local_version}"'",
                "remote_version": "'"${remote_version}"'",
                "session_key": "'"${session_key}"'",
                "timezone_offset": "'"${current_timezone}"'",
                "env": "'"${POSTHOG_ENV:-prod}"'"
            }
        }' > /dev/null 2>&1
}

CACHED_LATEST_VERSION=""

function get_latest_version {
    if [[ "${CACHED_LATEST_VERSION}" == "" ]]; then
        CACHED_LATEST_VERSION=$(curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | grep tag_name | awk -F'"' '{ print $4 }' | sed 's/ //g')
    fi
    echo "${CACHED_LATEST_VERSION}"
}

function get_local_version {
    if [[ -f "${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}" ]]; then
        cat "${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}"
    else
        echo "Missing"
    fi
}

function is_northslope_script_up_to_date {
    [[ "$(get_local_version)" == "$(get_latest_version)" ]] && [[ "$(get_local_version)" != "Missing" ]] && [[ "$(get_latest_version)" != "" ]]
}


function print_usage {
    echo "Usage: setup [OSDK_CLI_BRANCH]"
    echo "   This command will run the northslope setup script for your machine."
    echo "   You can optionally provide a specific branch of the OSDK CLI to install."
    echo ""
    echo "   Your Version  : $(get_local_version)"
    echo "   Latest Version: $(get_latest_version)"
    if ! is_northslope_script_up_to_date; then
        echo ""
        echo "   ⚠️ Script Outdated"
        echo "   This script will update itself the latest version before running"
    fi
}

case "$1" in
    --help|-h|help|version|--version|-v)
        print_usage
        exit 0
        ;;
    --skip-update|skip)
        SKIP_UPDATE=true
        shift
        ;;
esac

# Check if local version matches remote version, and self-update if needed
if [[ -z "${SKIP_UPDATE}" ]] && ! is_northslope_script_up_to_date; then
    echo "Updating self to latest version ($(get_latest_version))..."
    # Download the new northslope-setup.sh
    curl_output=$(curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/northslope-setup.sh -o "${NORTHSLOPE_NORTHSLOPE_SETUP_SCRIPT_PATH}" 2>&1)
    curl_exit_code=$?
    if [[ ${curl_exit_code} -ne 0 ]]; then
        error_msg="Failed to download updated northslope-setup.sh: ${curl_output}"
        echo "'northslope-setup' Failure 🚫"
        emit_wrapper_failure_event "${error_msg}" ${curl_exit_code} &
        echo "${error_msg}"
        exit 1
    fi

    # Update version file
    get_latest_version > "${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}"

    # Make executable and re-execute with the new version (exec replaces current process)
    chmod +x "${NORTHSLOPE_NORTHSLOPE_SETUP_SCRIPT_PATH}"
    exec /bin/zsh "${NORTHSLOPE_NORTHSLOPE_SETUP_SCRIPT_PATH}" "$@"
fi

echo "Running 'setup' version $(get_local_version)"

# Create a setup script so that we can pass in command line args
curl_output=$(curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/setup.sh -o "${NORTHSLOPE_SETUP_SCRIPT_PATH}" 2>&1)
curl_exit_code=$?
if [[ ${curl_exit_code} -ne 0 ]]; then
    error_msg="Failed to download setup.sh: ${curl_output}"
    echo "'northslope-setup' Failure 🚫"
    emit_wrapper_failure_event "${error_msg}" ${curl_exit_code} &
    exit 1
fi

exec /bin/zsh "${NORTHSLOPE_SETUP_SCRIPT_PATH}" "$@"
