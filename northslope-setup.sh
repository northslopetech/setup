#!/bin/zsh

CACHED_LATEST_VERSION=""

function get_latest_version {
    if [[ "${CACHED_LATEST_VERSION}" == "" ]]; then
        CACHED_LATEST_VERSION=$(curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | grep tag_name | awk -F'"' '{ print $4 }' | sed 's/ //g')
    fi
    echo "${CACHED_LATEST_VERSION}"
}

function print_usage {
    echo "Usage: setup"
    echo "   This command will run the northslope setup script for your machine."
    echo "   Your Version  : ${northslope_setup_version}"
    echo "   Latest Version: $(get_latest_version)"
}

northslope_setup_version=`cat ${HOME}/.northslope/setup-version`

if [[ ! -z $1 ]]; then
    # Prints the help message if any
    # arguments are passed. In the future,
    # we can check to make sure it's a '--help'
    print_usage
    exit 1
fi

/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/setup.sh)"
