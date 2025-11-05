#!/bin/zsh

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
