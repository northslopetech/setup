#!/bin/zsh

#==============================================================================
# CONFIGURATION & CONSTANTS
#==============================================================================

# Comprehensive tool result tracking
TOOL_NAMES=()
TOOL_STATUSES=()        # "already_installed", "installed", "failed"
TOOL_MESSAGES=()        # Additional context (error message, version, etc.)
TOOL_EXIT_CODES=()      # Exit code (relevant for failures)
TOOL_TIMESTAMPS=()      # ISO 8601 timestamp
TOOL_INSTALLERS=()      # How tool was installed: "asdf", "npm", "brew", "manual", "system"
TOOL_VERSIONS=()        # Version being installed

# Failure tracking arrays (for finalization summary)
FAILED_TOOLS=()
FAILURE_MESSAGES=()
FAILURE_CODES=()
FAILURE_TIMESTAMPS=()

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

CACHED_LATEST_VERSION=""

function get_latest_version {
    if [[ "${CACHED_LATEST_VERSION}" == "" ]]; then
        CACHED_LATEST_VERSION=$(curl -sL https://api.github.com/repos/northslopetech/setup/releases/latest | grep tag_name | awk -F'"' '{ print $4 }' | sed 's/ //g')
    fi
    echo "${CACHED_LATEST_VERSION}"
}

function get_timestamp {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

function print_check_msg {
    local tool=$1
    printf "Checking '${tool}'... "
}

function print_failed_install_msg {
    local tool=$1
    local error_msg=${2:-"Installation failed"}
    local exit_code=${3:-1}
    local installer=${4:-"manual"}
    local version=${5:-""}

    echo "'${tool}' Not Installed 🚫"
    echo "  Error: ${error_msg}"

    capture_failure "${tool}" "${error_msg}" "${exit_code}" "${installer}" "${version}"
}

function print_and_record_upgraded_msg {
    local tool=$1
    local version=$2
    local installer=${3:-"manual"}
    echo "'${tool}' Upgraded to ${version} 🔥"

    record_tool_result "${tool}" "upgraded" "" "0" "${installer}" "${version}"
}

function print_and_record_already_installed_msg {
    local tool=$1
    local version=${2:-""}
    local installer=${3:-"manual"}
    echo "'${tool}' Installed ✅"

    record_tool_result "${tool}" "already_installed" "" "0" "${installer}" "${version}"
}

function print_and_record_newly_installed_msg {
    local tool=$1
    local version=${2:-""}
    local installer=${3:-"manual"}
    echo "'${tool}' Newly Installed ✨"

    record_tool_result "${tool}" "installed" "" "0" "${installer}" "${version}"
}


function print_missing_msg {
    local tool=$1
    echo "Missing '${tool}'... Installing... "
}

function capture_failure {
    local tool=$1
    local error_msg=$2
    local exit_code=${3:-1}
    local installer=${4:-"manual"}
    local version=${5:-""}
    local timestamp=`get_timestamp`

    # Extract base tool name (everything before first space)
    local base_tool=$(echo "${tool}" | awk '{print $1}')

    # If version not provided, try to extract from tool name
    if [[ -z "${version}" && "${tool}" =~ " " ]]; then
        version=$(echo "${tool}" | awk '{print $2}')
    fi

    FAILED_TOOLS+=("${base_tool}")
    FAILURE_MESSAGES+=("${error_msg}")
    FAILURE_CODES+=("${exit_code}")
    FAILURE_TIMESTAMPS+=("${timestamp}")

    # Record in comprehensive tracking
    record_tool_result "${base_tool}" "failed" "${error_msg}" "${exit_code}" "${installer}" "${version}"

    # Emit individual failure event to PostHog
    emit_failure_event "${base_tool}" "${error_msg}" "${exit_code}" "${timestamp}" &
}

function record_tool_result {
    local tool=$1
    local tool_status=$2         # "already_installed", "installed", "failed"
    local message=${3:-""}       # Optional message
    local exit_code=${4:-0}      # Exit code (default 0)
    local installer=${5:-"manual"}  # How installed: "asdf", "npm", "brew", "manual", "system"
    local version=${6:-""}       # Version being installed
    local timestamp=`get_timestamp`

    TOOL_NAMES+=("${tool}")
    TOOL_STATUSES+=("${tool_status}")
    TOOL_MESSAGES+=("${message}")
    TOOL_EXIT_CODES+=("${exit_code}")
    TOOL_TIMESTAMPS+=("${timestamp}")
    TOOL_INSTALLERS+=("${installer}")
    TOOL_VERSIONS+=("${version}")
}

#==============================================================================
# ANALYTICS FUNCTIONS
#==============================================================================

POSTHOG_KEY=phc_Me99GOmroO6r5TiJwJoD3VpSoBr6JbWk3lo9rrLkEyQ
session_key="`date +%s`-$(( ( $RANDOM % 100 ) + 1 ))"
current_timezone=`date "+%z"`

function emit_failure_event {
    local tool=$1
    local error_msg=$2
    local exit_code=$3
    local timestamp=$4
    local LATEST_SCRIPT_VERSION=`get_latest_version`

    # Escape error message for JSON (backslashes first, then quotes)
    local escaped_error_msg=$(echo "${error_msg}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr -d '\n' | tr -d '\r')
    local escaped_tool=$(echo "${tool}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    # Build exception list
    local exception_list="[{\"type\":\"SetupFailure:${escaped_tool}\",\"value\":\"${escaped_error_msg}\",\"mechanism\":{\"type\":\"shell_script\",\"handled\":false},\"module\":\"${escaped_tool}\"}]"

    curl --silent -XPOST https://us.i.posthog.com/capture/ \
        --header "Content-Type: application/json" \
        --data '{
            "api_key": "'"${POSTHOG_KEY}"'",
            "event": "$exception",
            "properties": {
                "distinct_id": "'"${USER}"'",
                "user": "'"${USER}"'",
                "timestamp": "'"${timestamp}"'",
                "$exception_type": "SetupFailure:'"${escaped_tool}"'",
                "$exception_message": "'"${escaped_error_msg}"'",
                "$exception_level": "error",
                "$exception_list": '"${exception_list}"',
                "$exception_fingerprint": "setup-installation-failure-'"${escaped_tool}"'-'"${session_key}"'",
                "tool": "'"${escaped_tool}"'",
                "exit_code": '"${exit_code}"',
                "session_key": "'"${session_key}"'",
                "timezone_offset": "'"${current_timezone}"'",
                "latest_version": "'"${LATEST_SCRIPT_VERSION}"'",
                "env": "'"${POSTHOG_ENV:-prod}"'"
            }
        }' > /dev/null 2>&1
}

function emit_setup_started_event {
    local LATEST_SCRIPT_VERSION=`get_latest_version`
    curl --silent -XPOST https://us.i.posthog.com/capture/ \
        --header "Content-Type: application/json" \
        --data '{
            "api_key": "'"${POSTHOG_KEY}"'",
            "event": "setup:started",
            "properties": {
                "distinct_id": "'"${USER}"'",
                "user": "'"${USER}"'",
                "timezone_offset": "'"${current_timezone}"'",
                "session_key": "'"${session_key}"'",
                "timestamp": "'"`get_timestamp`"'",
                "latest_version": "'"${LATEST_SCRIPT_VERSION}"'",
                "env": "'"${POSTHOG_ENV:-prod}"'"
            }
        }' > /dev/null 2>&1
}

function emit_setup_finished_event {
    local LATEST_SCRIPT_VERSION=`get_latest_version`
    local success="true"
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        success="false"
    fi

    # Build complete results JSON object
    local results_json="{"

    # Count each status type
    local already_installed_count=0
    local installed_count=0
    local failed_count=0

    # Build tools object
    local tools_json="{"
    local sep=""
    for i in {1..${#TOOL_NAMES[@]}}; do
        # Escape strings for JSON (backslashes first, then quotes)
        local escaped_name=$(echo "${TOOL_NAMES[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        local escaped_msg=$(echo "${TOOL_MESSAGES[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr -d '\n' | tr -d '\r')
        local escaped_installer=$(echo "${TOOL_INSTALLERS[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        local escaped_version=$(echo "${TOOL_VERSIONS[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

        tools_json+="${sep}\"${escaped_name}\": {\"tool\":\"${escaped_name}\",\"status\":\"${TOOL_STATUSES[$i]}\",\"installer\":\"${escaped_installer}\",\"version\":\"${escaped_version}\",\"message\":\"${escaped_msg}\",\"exit_code\":${TOOL_EXIT_CODES[$i]},\"timestamp\":\"${TOOL_TIMESTAMPS[$i]}\"}"

        # Count status types
        case "${TOOL_STATUSES[$i]}" in
            "already_installed") ((already_installed_count++)) ;;
            "installed") ((installed_count++)) ;;
            "failed") ((failed_count++)) ;;
        esac
        sep=","
    done
    tools_json+="}"

    results_json+="\"tools\":${tools_json},\"summary\":{\"already_installed\":${already_installed_count},\"installed\":${installed_count},\"failed\":${failed_count},\"total\":${#TOOL_NAMES[@]}}"
    results_json+="}"

    curl --silent -XPOST https://us.i.posthog.com/capture/ \
        --header "Content-Type: application/json" \
        --data '{
            "api_key": "'"${POSTHOG_KEY}"'",
            "event": "setup:finished",
            "properties": {
                "distinct_id": "'"${USER}"'",
                "user": "'"${USER}"'",
                "timezone_offset": "'"${current_timezone}"'",
                "session_key": "'"${session_key}"'",
                "timestamp": "'"`get_timestamp`"'",
                "latest_version": "'"${LATEST_SCRIPT_VERSION}"'",
                "env": "'"${POSTHOG_ENV:-prod}"'",
                "success": '"${success}"',
                "results": '"${results_json}"'
            }
        }' > /dev/null 2>&1
}

#==============================================================================
# INSTALLATION HELPER FUNCTIONS
#==============================================================================

function check_home_version_set {
    local tool=$1
    local version=$2
    # Use anchored grep to match only lines starting with the tool name followed by a space
    tool_version=`cat ${HOME}/.tool-versions | grep "^${tool} " | cut -d' ' -f2`
    if [[ "${tool_version}" == "${version}" ]]; then
        return 0
    else
        return 1
    fi
}

function asdf_install_and_set {
    local tool=$1
    local version=$2

    print_check_msg ${tool}

    # Check if tool is already installed at the requested version
    asdf list ${tool} ${version} 2>&1 | grep "No compatible versions installed" > /dev/null 2>&1
    local already_installed=$?

    # No-op if plugin exists
    plugin_output=$(asdf plugin add ${tool} 2>&1)
    plugin_status=$?

    # No-op if command is installed
    install_output=$(asdf install ${tool} ${version} 2>&1)
    install_status=$?

    # Check if installation was successful
    if [[ ${install_status} -ne 0 ]]; then
        # Check if it was already installed (exit code 0 means success, which means not installed)
        if [[ ${already_installed} -ne 0 ]]; then
            # Was already installed, just continue
            print_and_record_already_installed_msg "${tool}" "${version}" "asdf"
            return 0
        fi
        # Installation failed
        print_failed_install_msg "${tool} ${version}" "asdf install failed: ${install_output}" ${install_status} "asdf" "${version}"
        return 1
    fi

    check_home_version_set ${tool} ${version}
    if [[ $? -ne 0 ]]; then
        # If a home version is not chosen
        # we choose the default version
        # TODO: Can we compare versions and
        # forcibly upgrade if an old one is set?
        set_output=$(asdf set --home ${tool} ${version} 2>&1)
        set_status=$?
        if [[ ${set_status} -ne 0 ]]; then
            print_failed_install_msg "${tool} ${version}" "asdf set --home failed: ${set_output}" ${set_status} "asdf" "${version}"
            return 1
        fi
    fi

    # Check if it was already installed before we ran install
    if [[ ${already_installed} -ne 0 ]]; then
        print_and_record_already_installed_msg "${tool}" "${version}" "asdf"
    else
        print_and_record_newly_installed_msg "${tool}" "${version}" "asdf"
    fi
}

#==============================================================================
# MAIN EXECUTION FLOW
#==============================================================================

#------------------------------------------------------------------------------
# Initialization
#------------------------------------------------------------------------------

NORTHSLOPE_DIR=${HOME}/.northslope
emit_setup_started_event &

mkdir -p $NORTHSLOPE_DIR > /dev/null 2>&1

# Remove old versions of script and cache
for f in ${HOME}/.northslope*; do
    if [[ -d ${f} ]]; then
        continue
    fi
    rm ${f}
done

#------------------------------------------------------------------------------
# Setup Command Installation
#------------------------------------------------------------------------------

NORTHSLOPE_SETUP_SCRIPT_PATH=${NORTHSLOPE_DIR}/northslope-setup.sh
NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH=${NORTHSLOPE_DIR}/setup-version

# Add `setup` command to .zshrc
TOOL=setup
print_check_msg ${TOOL}
touch ~/.zshrc
cat ~/.zshrc | grep "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" > /dev/null 2>&1
SETUP_ALREADY_INSTALLED=$?
if [[ ${SETUP_ALREADY_INSTALLED} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    # Remove old setup alias
    TEMP_ZSHRC=${NORTHSLOPE_DIR}/temp-zshrc
    cat ${HOME}/.zshrc | fgrep -v "alias setup=\"" | fgrep -v "# Added by Northslope" > ${TEMP_ZSHRC}
    # Add the new alias
    echo "" >> ${TEMP_ZSHRC}
    echo "# Added by Northslope" >> ${TEMP_ZSHRC}
    echo "alias setup=\"${NORTHSLOPE_SETUP_SCRIPT_PATH}\"" >> ${TEMP_ZSHRC}
    # Backup the .zshrc file
    cp ${HOME}/.zshrc ${HOME}/.zshrc.bak
    # Over write the .zshrc
    # cat used here in case .zshrc is symlinked
    cat ${TEMP_ZSHRC} > ${HOME}/.zshrc
    rm ${TEMP_ZSHRC}
    alias setup="${NORTHSLOPE_SETUP_SCRIPT_PATH}"
    chmod +x ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/northslope-setup.sh > ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    get_latest_version > $NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH
    print_and_record_newly_installed_msg ${TOOL}
else
    IS_UPGRADING=1
    if [[ -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} ]]; then
        current_version=`cat ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}`
        if [[ "${current_version}" != "`get_latest_version`" ]]; then
            IS_UPGRADING=0
        fi
    fi
    if [[ ${IS_UPGRADING} -eq 0 ]]; then
        curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/northslope-setup.sh > ${NORTHSLOPE_SETUP_SCRIPT_PATH}
        get_latest_version > $NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH
        print_and_record_upgraded_msg ${TOOL} `get_latest_version`
    else
        print_and_record_already_installed_msg ${TOOL}
    fi
fi


chmod +x ${NORTHSLOPE_SETUP_SCRIPT_PATH}

#------------------------------------------------------------------------------
# Package Managers
#------------------------------------------------------------------------------

# Install Brew
TOOL=brew
print_check_msg ${TOOL}
cat ~/.zshrc | grep "brew shellenv" > /dev/null 2>&1
missing=$?
brew --help > /dev/null 2>&1
usable=$?
BREW_ALREADY_INSTALLED=0
if [[ ${missing} -ne 0 || ${usable} -ne 0 ]]; then
    BREW_ALREADY_INSTALLED=1
    print_missing_msg ${TOOL}
    echo "   ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  "
    echo "  ⚠️ Please read the following directions ⚠️"
    echo "  ⚠️ carefully. You may be asked for your ⚠️"
    echo "  ⚠️ password, which is the password for  ⚠️"
    echo "  ⚠️ your computer. Please be prepared.   ⚠️"
    echo "  Press Enter once you have your computer password..."
    read
    echo "  ⚠️ The following command can take upwards of 10-20 minutes, depending on your internet connection."
    echo "  ⚠️ Please be patient, but if you need to cancel at any time, press Ctrl+C"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval $(/opt/homebrew/bin/brew shellenv)
fi

# Ensure brew shellenv export is in .zshrc if missing
cat ~/.zshrc | grep "brew shellenv" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> $HOME/.zshrc
fi

# Verify brew is working after installation
brew_error=$(brew --help 2>&1)
brew_exit_code=$?
if [[ ${brew_exit_code} -ne 0 ]]; then
    print_failed_install_msg ${TOOL} "Brew installation failed or is not in PATH: ${brew_error}" ${brew_exit_code} "brew" ""
    echo "Cannot go on without brew. Please contact @tnguyen."
    exit 1
else
    BREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    if [[ ${BREW_ALREADY_INSTALLED} -eq 0 ]]; then
        print_and_record_already_installed_msg ${TOOL} ${BREW_VERSION} "brew"
    else
        print_and_record_newly_installed_msg ${TOOL} ${BREW_VERSION} "brew"
    fi
fi

# Install asdf
TOOL=asdf
print_check_msg ${TOOL}
asdf --help > /dev/null 2>&1
ASDF_ALREADY_INSTALLED=$?
if [[ ${ASDF_ALREADY_INSTALLED} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    brew install asdf
    ASDF_VERSION=$(asdf --version 2>/dev/null | awk '{print $1}' || echo "")
    print_and_record_newly_installed_msg ${TOOL} ${ASDF_VERSION} "brew"
else
    ASDF_VERSION=$(asdf --version 2>/dev/null | awk '{print $1}' || echo "")
    print_and_record_already_installed_msg ${TOOL} ${ASDF_VERSION} "brew"
fi
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Check asdf is in zshrc
TOOL="asdf in .zshrc"
print_check_msg ${TOOL}
cat ~/.zshrc | grep 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' > /dev/null 2>&1
ASDF_ZSHRC_ALREADY_INSTALLED=$?
if [[ ${ASDF_ZSHRC_ALREADY_INSTALLED} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> $HOME/.zshrc
    print_and_record_newly_installed_msg ${TOOL}
else
    print_and_record_already_installed_msg ${TOOL}
fi

#------------------------------------------------------------------------------
# Git Configuration
#------------------------------------------------------------------------------

# Check for git config name
TOOL="git config name"
print_check_msg ${TOOL}
git config --global user.name > /dev/null 2>&1
GIT_NAME_ALREADY_SET=$?
GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}' || echo "")
if [[ ${GIT_NAME_ALREADY_SET} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    echo "What is your full name?"
    echo "ex. Tam Nguyen"
    read git_name
    git config --global user.name "${git_name}"
    print_and_record_newly_installed_msg ${TOOL} ${GIT_VERSION}
else
    print_and_record_already_installed_msg ${TOOL} ${GIT_VERSION}
fi

# Check for git config email
TOOL="git config email"
print_check_msg ${TOOL}
git config --global user.email > /dev/null 2>&1
GIT_EMAIL_ALREADY_SET=$?
if [[ ${GIT_EMAIL_ALREADY_SET} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    echo "What is your email address?"
    echo "ex. test@northslopetech.com"
    read git_email
    git config --global user.email "${git_email}"
    print_and_record_newly_installed_msg ${TOOL} ${GIT_VERSION}
else
    print_and_record_already_installed_msg ${TOOL} ${GIT_VERSION}
fi

# Check for git config push.autoSetupRemote
TOOL="git config push.autoSetupRemote"
print_check_msg ${TOOL}
git config --global push.autoSetupRemote | grep "true" > /dev/null 2>&1
GIT_PUSH_ALREADY_SET=$?
if [[ ${GIT_PUSH_ALREADY_SET} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    git config --global push.autoSetupRemote true
    print_and_record_newly_installed_msg ${TOOL} ${GIT_VERSION}
else
    print_and_record_already_installed_msg ${TOOL} ${GIT_VERSION}
fi

#------------------------------------------------------------------------------
# Development Tools
#------------------------------------------------------------------------------

# Install Cursor
TOOL=cursor
print_check_msg ${TOOL}
if [[ ! -d "/Applications/Cursor.app" ]]; then
    print_missing_msg ${TOOL}
    brew install --cask cursor
    CURSOR_VERSION=$(plutil -p /Applications/Cursor.app/Contents/Info.plist 2>/dev/null | grep CFBundleShortVersionString | awk -F'"' '{print $4}' || echo "")
    print_and_record_newly_installed_msg ${TOOL} ${CURSOR_VERSION} "brew"
else
    CURSOR_VERSION=$(plutil -p /Applications/Cursor.app/Contents/Info.plist 2>/dev/null | grep CFBundleShortVersionString | awk -F'"' '{print $4}' || echo "")
    print_and_record_already_installed_msg ${TOOL} ${CURSOR_VERSION} "brew"
fi

# Install claude code
TOOL=claude
print_check_msg ${TOOL}
claude --version > /dev/null 2>&1
CLAUDE_ALREADY_INSTALLED=$?
if [[ ${CLAUDE_ALREADY_INSTALLED} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    brew install --cask claude-code
    CLAUDE_VERSION=$(claude --version 2>/dev/null | awk '{print $2}' || echo "")
    print_and_record_newly_installed_msg ${TOOL} ${CLAUDE_VERSION} "brew"
else
    CLAUDE_VERSION=$(claude --version 2>/dev/null | awk '{print $2}' || echo "")
    print_and_record_already_installed_msg ${TOOL} ${CLAUDE_VERSION} "brew"
fi

#------------------------------------------------------------------------------
# Programming Languages & Tools (via asdf)
#------------------------------------------------------------------------------

# Install all of the following tools using asdf
asdf_tools=(
    nodejs__24.11.0
    pnpm__10.20.0
    python__3.13.9
    github-cli__2.83.0
    uv__0.9.7
    jq__1.8.1
    direnv__2.37.1
    java__openjdk-17.0.2
)

for asdf_tool in ${asdf_tools[@]}; do
    tool=${asdf_tool%__*}
    version=${asdf_tool#*__}
    asdf_install_and_set ${tool} ${version}
done
asdf reshim

#------------------------------------------------------------------------------
# Direnv Hook Setup
#------------------------------------------------------------------------------

# Set up direnv to be hooked into zsh
TOOL="direnv hook"
direnv --version > /dev/null 2>&1
DIRENV_INSTALLED=$?
print_check_msg "${TOOL}"

cat ~/.zshrc | grep "eval \"$(direnv hook zsh)\"" > /dev/null 2>&1
DIRENV_HOOK_IS_SETUP=$?

if [[ ${DIRENV_INSTALLED} -ne 0 ]]; then
    print_failed_install_msg "${TOOL}" "direnv was not installed" ${install_status} "manual" "${version}"
else
    if [[ ${DIRENV_HOOK_IS_SETUP} -ne 0 ]]; then
        echo 'eval "$(direnv hook zsh)"' >> $HOME/.zshrc
        print_and_record_newly_installed_msg "${TOOL}"
    else
        print_and_record_already_installed_msg "${TOOL}"
    fi
fi

#------------------------------------------------------------------------------
# Authentication
#------------------------------------------------------------------------------

# Ensure logged in with `gh auth`
TOOL="gh auth"
print_check_msg "${TOOL}"
gh auth status > /dev/null 2>&1
GH_AUTH_ALREADY_SET=$?
if [[ ${GH_AUTH_ALREADY_SET} -ne 0 ]]; then
    echo "Not authorized. Authenticating..."
    echo "   ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  "
    echo "  ⚠️ Answers for the Following Questions ⚠️:"
    echo ""
    echo "  1️⃣ Where do you use Github?"
    echo "       'Github.com'"
    echo "  2️⃣ What is your preferred protocol for Git operations?"
    echo "      'SSH'"
    echo "       If you do have a key already, you can select it"
    echo "       If you don't have a key, you can generate it with the CLI"
    echo "           1️⃣ Enter a passphrase for your new SSH key (Optional): 'Leave blank and press enter'"
    echo "           2️⃣ Title for your SSH key: 'Press enter to use Github CLI default'"
    echo "  3️⃣ How would you like to authenticate Github CLI? 'Login with a web browser'"
    echo "       Copy the XXXX-XXXX token that you see in the terminal and press enter to open your browser."
    echo "          Login to github with the browser window and paste the XXXX-XXXX token into the web page."
    echo ""
    echo "   ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  "
    echo "  ⚠️ See Above for Answers for the Following Questions ⚠️"
    gh auth login
    gh_auth_status=$?
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}' || echo "")
    if [[ ${gh_auth_status} -eq 0 ]]; then
        echo "'gh auth' Authorized ✅"
        print_and_record_newly_installed_msg ${TOOL} ${GH_VERSION} "gh"
    else
        print_failed_install_msg "${TOOL}" "gh auth login failed or was interrupted" ${gh_auth_status} "system" "${GH_VERSION}"
    fi
else
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}' || echo "")
    print_and_record_already_installed_msg ${TOOL} ${GH_VERSION} "gh"
fi

#------------------------------------------------------------------------------
# Northslope Tools
#------------------------------------------------------------------------------

# Installing osdk-cli
TOOL="osdk-cli"
print_check_msg "${TOOL}"
osdk-cli --version > /dev/null 2>&1
OSDK_ALREADY_INSTALLED=$?
CURR_OSDK_VERSION=""
if [[ ${OSDK_ALREADY_INSTALLED} -eq 0 ]]; then
    CURR_OSDK_VERSION=$(osdk-cli --version 2>/dev/null | awk '{print $1}' || echo "")
fi

install_output=$(npm install -g @northslopetech/osdk-cli 2>&1)
install_status=$?
if [[ ${install_status} -eq 0 ]]; then
    NEW_OSDK_VERSION=$(osdk-cli --version 2>/dev/null | awk '{print $1}' || echo "")
    if [[ ${OSDK_ALREADY_INSTALLED} -eq 0 ]]; then
        if [[ "${NEW_OSDK_VERSION}" != "${CURR_OSDK_VERSION}" ]]; then
            print_and_record_upgraded_msg ${TOOL} ${NEW_OSDK_VERSION} "npm"
        else
            print_and_record_already_installed_msg ${TOOL} ${NEW_OSDK_VERSION} "npm"
        fi
    else
        print_and_record_newly_installed_msg ${TOOL} ${NEW_OSDK_VERSION} "npm"
    fi
else
    print_failed_install_msg "${TOOL}" "npm install failed: ${install_output}" ${install_status} "npm" ""
fi

#------------------------------------------------------------------------------
# Finalization
#------------------------------------------------------------------------------

echo
if [[ ${#FAILED_TOOLS[@]} -eq 0 ]]; then
    echo "Northslope Setup Complete! ✅"
    echo
    echo "Run 'setup' in the future to get the latest and greatest tools"
    echo "Please close and reopen your terminal to continue..."
else
    echo "Northslope Setup Failed! 🚫"
    echo
    echo "The following tools failed to install:"
    echo "========================================="
    for i in {1..${#FAILED_TOOLS[@]}}; do
        echo
        echo "🚫 ${FAILED_TOOLS[$i]}"
        echo "   Error: ${FAILURE_MESSAGES[$i]}"
        echo "   Exit Code: ${FAILURE_CODES[$i]}"
        echo "   Time: ${FAILURE_TIMESTAMPS[$i]}"
    done
    echo
    echo "========================================="
    echo "Please contact @tnguyen and show him your terminal output."
fi

emit_setup_finished_event &
