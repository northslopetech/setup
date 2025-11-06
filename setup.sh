#!/bin/zsh

function get_latest_version {
    curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | jq -r '.tag_name' | sed 's/\s//g' | sed 's/\n//g'
}

NORTHSLOPE_SETUP_SCRIPT_PATH=${HOME}/.northslope-setup.sh
NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH=${HOME}/.northslope-setup-version 

# Add `setup` command to .zshrc
cat ~/.zshrc | grep "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" >> $HOME/.zshrc
    alias setup="${NORTHSLOPE_SETUP_SCRIPT_PATH}"
fi
echo "Installed"


IS_UPGRADING=0
if [[ -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} ]]; then
    current_version=`cat ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}`
    if [[ "${current_version}" != "`get_latest_version`" ]]; then
        echo "❌ Local 'setup' version is out of date."
        IS_UPGRADING=1
    else
        echo "Version is up to date: ${current_version}"
    fi
fi

if [[ ! -e ${NORTHSLOPE_SETUP_SCRIPT_PATH} || ! -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} || ${IS_UPGRADING} -eq 1 ]]; then
    if [ ${IS_UPGRADING} -eq 0 ]; then
        # Show only if we are not upgrading
        echo "‼ Missing '`basename ${NORTHSLOPE_SETUP_SCRIPT_PATH}`' script. Installing..."
    else
        echo "‼ Upgrading '`basename ${NORTHSLOPE_SETUP_SCRIPT_PATH}`' script..."
    fi
    curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/tags/latest/northslope-setup.sh > ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    get_latest_version > $NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH
else
    echo "`basename ${NORTHSLOPE_SETUP_SCRIPT_PATH}` is ok"
fi

chmod +x ${NORTHSLOPE_SETUP_SCRIPT_PATH}

# Install Brew
cat ~/.zshrc | grep "brew shellenv" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Missing brew. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> $HOME/.zshrc
    eval $(/opt/homebrew/bin/brew shellenv)
fi

# Install asdf
asdf --help > /dev/null
if [[ $? -ne 0 ]]; then
    echo "Missing asdf. Installing..."
    brew install asdf
    echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> $HOME/.zshrc
    export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

export TARGET_DEFAULT_GLOBAL_NODE=24.11.0
# Install npm
npm help > /dev/null 2>&1 && which npm | grep asdf > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Missing nodejs. Installing..."
    asdf plugin add nodejs
    asdf install nodejs ${TARGET_DEFAULT_GLOBAL_NODE}
    asdf set --home nodejs ${TARGET_DEFAULT_GLOBAL_NODE}
fi

# Install pnpm
pnpm --help > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Missing pnpm. Installing..."
    npm install -g pnpm
fi

# Install python
export TARGET_DEFAULT_GLOBAL_PYTHON=3.13.9
python --help > /dev/null 2>&1 && which python | grep asdf > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Missing python. Installing..."
    asdf plugin add python
    asdf install python ${TARGET_DEFAULT_GLOBAL_PYTHON}
    asdf set --home python ${TARGET_DEFAULT_GLOBAL_PYTHON}
fi

# Install GitHub CLI
gh --version > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Missing GitHub CLI. Installing..."
    brew install gh
fi

asdf reshim

echo "Setup Complete!"
