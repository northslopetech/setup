#!/bin/zsh

function get_latest_version {
    curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | jq -r '.tag_name' | sed 's/\s//g' | sed 's/\n//g'
}

function print_check_msg {
    local tool=$1
    printf "Checking '${tool}'... "
}

function print_installed_msg {
    local tool=$1
    echo "'${tool}' Installed ✅"
}

function print_missing_msg {
    local tool=$1
    echo "Missing '${tool}'... Installing... "
}

NORTHSLOPE_SETUP_SCRIPT_PATH=${HOME}/.northslope-setup.sh
NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH=${HOME}/.northslope-setup-version 

# Add `setup` command to .zshrc
TOOL=setup
print_check_msg ${TOOL}
cat ~/.zshrc | grep "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    echo "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" >> $HOME/.zshrc
    alias setup="${NORTHSLOPE_SETUP_SCRIPT_PATH}"
fi
print_installed_msg ${TOOL}


print_check_msg "setup version"
IS_UPGRADING=0
if [[ -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} ]]; then
    current_version=`cat ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}`
    if [[ "${current_version}" != "`get_latest_version`" ]]; then
        echo "Local 'setup' version is out of date. 🚫"
        IS_UPGRADING=1
    else
        echo "Version is up to date: ${current_version} ✅"
    fi
else
    echo "No local version set 🚫 "
fi

# Setup command comes after setup version
# since setup version will inform setup command
TOOL="setup command"
if [ ${IS_UPGRADING} -eq 0 ]; then
    print_check_msg ${TOOL}
fi
if [[ ! -e ${NORTHSLOPE_SETUP_SCRIPT_PATH} || ! -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} || ${IS_UPGRADING} -eq 1 ]]; then
    if [ ${IS_UPGRADING} -eq 0 ]; then
        # Show only if we are not upgrading
        print_missing_msg ${TOOL}
    else
        echo "Upgrading ${TOOL}..."
    fi
    curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/tags/latest/northslope-setup.sh > ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    get_latest_version > $NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH
fi
print_installed_msg ${TOOL}

chmod +x ${NORTHSLOPE_SETUP_SCRIPT_PATH}

# Install Brew
TOOL=brew
print_check_msg ${TOOL}
cat ~/.zshrc | grep "brew shellenv" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> $HOME/.zshrc
    eval $(/opt/homebrew/bin/brew shellenv)
fi
print_installed_msg ${TOOL}

# Install asdf
TOOL=asdf
print_check_msg ${TOOL}
asdf --help > /dev/null
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    brew install asdf
    echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> $HOME/.zshrc
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi
print_installed_msg ${TOOL}

export TARGET_DEFAULT_GLOBAL_NODE=24.11.0
# Install npm
TOOL=nodejs
print_check_msg ${TOOL}
npm help > /dev/null 2>&1 && which npm | grep asdf > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    asdf plugin add nodejs
    asdf install nodejs ${TARGET_DEFAULT_GLOBAL_NODE}
    asdf set --home nodejs ${TARGET_DEFAULT_GLOBAL_NODE}
fi
print_installed_msg ${TOOL}

# Install pnpm
TOOL=pnpm
print_check_msg ${TOOL}
pnpm --help > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    npm install -g pnpm
fi
print_installed_msg ${TOOL}

# Install python
TOOL=python
print_check_msg ${TOOL}
export TARGET_DEFAULT_GLOBAL_PYTHON=3.13.9
python --help > /dev/null 2>&1 && which python | grep asdf > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    asdf plugin add python
    asdf install python ${TARGET_DEFAULT_GLOBAL_PYTHON}
    asdf set --home python ${TARGET_DEFAULT_GLOBAL_PYTHON}
fi
print_installed_msg ${TOOL}

# Install GitHub CLI
TOOL=gh
print_check_msg ${TOOL}
gh --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    print_missing_msg ${TOOL}
    brew install gh
fi
print_installed_msg ${TOOL}

asdf reshim

echo "Northslope Setup Complete! ✅"
echo
echo "Run 'setup' in the future to get the latest and greatest tools"
