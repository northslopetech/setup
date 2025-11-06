#!/bin/zsh

function get_latest_version {
    curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | jq -r '.tag_name' | sed 's/\s//g' | sed 's/\n//g'
}

function print_usage {
    echo "Usage: setup"
    echo "   This command will run the northslope setup script for your machine."
    echo "   Your Version  : ${northslope_setup_version}"
    echo "   Latest Version: $(get_latest_version)"
}

northslope_setup_version=`cat ${HOME}/.northslope-setup-version`

if [[ ! -z $1 ]]; then
    # Prints the help message if any
    # arguments are passed. In the future,
    # we can check to make sure it's a '--help'
    print_usage
    exit 1
fi

/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/tags/latest/setup.sh)"
