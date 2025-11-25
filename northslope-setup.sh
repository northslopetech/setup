#!/bin/zsh

function get_latest_version {
    curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | jq -r '.tag_name' | sed 's/\s//g' | sed 's/\n//g'
}

function print_usage {
    echo "Usage: setup [OSDK_CLI_BRANCH]"
    echo "   This command will run the northslope setup script for your machine."
    echo "   You can optionally provide a specific branch of the OSDK CLI to install."
    echo ""
    echo "   Your Version  : ${northslope_setup_version}"
    echo "   Latest Version: $(get_latest_version)"
}

northslope_setup_version=`cat ${HOME}/.northslope/setup-version`

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
    print_usage
    exit 0
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
