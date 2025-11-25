#!/bin/zsh

CACHED_LATEST_VERSION=""

function get_latest_version {
    if [[ "${CACHED_LATEST_VERSION}" == "" ]]; then
        CACHED_LATEST_VERSION=$(curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | grep tag_name | awk -F'"' '{ print $4 }' | sed 's/ //g')
    fi
    echo "${CACHED_LATEST_VERSION}"
}

function get_local_version {
    if [[ -f "${HOME}/.northslope/setup-version" ]]; then
        cat ${HOME}/.northslope/setup-version
    else
        echo ""
    fi
}

function is_up_to_date {
    local_version=$(get_local_version)
    latest_version=$(get_latest_version)
    if [[ "${local_version}" == "${latest_version}" ]]; then
        return 0
    else
        return 1
    fi
}

function print_usage {
    echo "Usage: setup [OSDK_CLI_BRANCH]"
    echo "   This command will run the northslope setup script for your machine."
    echo "   You can optionally provide a specific branch of the OSDK CLI to install."
    echo ""
    echo "   Your Version  : $(get_local_version)"
    echo "   Latest Version: $(get_latest_version)"
    echo ""
    if [[ $(is_up_to_date) -ne 0 ]]; then
    echo "   This script will be updated to the latest version before running."
    fi
}

northslope_setup_version=`cat ${HOME}/.northslope/setup-version`

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
    print_usage
    exit 0
fi

# Check if local version matches remote version, and self-update if needed
if [[ is_up_to_date -ne 0 ]]; then
    echo "Updating setup command from ${northslope_setup_version} to ${remote_version}..."

    # Download the new northslope-setup.sh
    new_script="${HOME}/.northslope/northslope-setup.sh"
    curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/northslope-setup.sh > "${new_script}"
    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to download the updated setup script."
        exit 1
    fi

    # Update version file
    echo "${remote_version}" > ${HOME}/.northslope/setup-version

    # Make executable and re-execute with the new version (exec replaces current process)
    chmod +x "${new_script}"
    exec /bin/zsh "${new_script}" "$@"
    exit $?
fi

# Create a temp setup script so that we can pass in command line args
setup_script=`mktemp`
curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/setup.sh > ${setup_script}
if [[ $? -ne 0 ]]; then
    echo "Error: Unable to download the northslope setup script."
    exit 1
fi
/bin/zsh ${setup_script} "$@"
exit_code=$?
rm ${setup_script}
exit ${exit_code}
