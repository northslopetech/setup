#!/bin/zsh

#                                         XX                                      
#                                       XX  XX                                    
#                                     XX      X                                   
#                                    X         XX                                 
#                                  XX            XX                               
#                                XX                X                              
#                               X                   XX                            
#                             XX                      X                           
#                           XX                    XX   XX                         
#                          X                    XX  XX   XX                       
#                        XX                   XX      X    X                      
#                      XX                    X         XX   XX                    
#                     X                    XX            XX   X                   
#                   XX                   XX                X   XX                 
#                 XX                    X                   XX   X                
#                X                    XX                      X   XX              
#              XX                   XX   XX                    XX   XX            
#            XX                   XX   XX  X                     X    X           
#           X                    X    X     XX                    XX   XX         
#         XX                   XX   XX        X                     X    X        
#       XX                   XX   XX           XX                    XX   XX      
#      X                   XXXXXXX               XX                    XX   XX    
#    XX                                            X                     X    X   
#  XX                                               XX                    XX   XX 
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX                     XXXXXX

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

    echo "'${tool}' Not Ready 🚫"
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
    echo "'${tool}' Ready ✅"

    record_tool_result "${tool}" "already_installed" "" "0" "${installer}" "${version}"
}

function print_and_record_newly_installed_msg {
    local tool=$1
    local version=${2:-""}
    local installer=${3:-"manual"}
    echo "'${tool}' New ✨"

    record_tool_result "${tool}" "installed" "" "0" "${installer}" "${version}"
}


function print_missing_msg {
    local tool=$1
    echo "Missing '${tool}'... "
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

    # Escape error message for JSON (backslashes first, then quotes, then newlines)
    local escaped_error_msg=$(printf '%s' "${error_msg}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{if(NR>1)printf "\\n"; printf "%s", $0}' | tr -d '\r')
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
        # Escape strings for JSON (backslashes first, then quotes, then newlines)
        local escaped_name=$(echo "${TOOL_NAMES[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        local escaped_msg=$(printf '%s' "${TOOL_MESSAGES[$i]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{if(NR>1)printf "\\n"; printf "%s", $0}' | tr -d '\r')
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
    touch "${HOME}/.tool-versions"
    tool_version=`cat "${HOME}/.tool-versions" | grep "^${tool} " | cut -d' ' -f2`
    if [[ "${tool_version}" == "${version}" ]]; then
        return 0
    else
        return 1
    fi
}

function get_tool_version {
    local tool=$1
    local version_index=$2
    local version_cmd="${tool} --version"
    eval ${version_cmd} 2>&1 | head -1 | awk "{print \$${version_index}}" || echo ""
}

function brew_install_tool {
    local tool=$1
    local version_index=$2
    local cask_flag="${3:-""}"
    local brew_package="${4:-$tool}"

    print_check_msg ${tool}

    ${tool} --version > /dev/null 2>&1
    local already_installed=$?

    if [[ ${already_installed} -ne 0 ]]; then
        print_missing_msg ${tool}
        brew install ${cask_flag} ${brew_package}
        local version=$(get_tool_version ${tool} ${version_index})
        print_and_record_newly_installed_msg "${tool}" "${version}" "brew"
    else
        local version=$(get_tool_version ${tool} ${version_index})
        print_and_record_already_installed_msg "${tool}" "${version}" "brew"
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

    # Check if plugin add was successful
    if [[ ${plugin_status} -ne 0 ]]; then
        print_failed_install_msg "${tool} ${version}" "asdf install failed: ${plugin_output}" ${plugin_status} "asdf" "${version}"
        return 1
    fi

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

NORTHSLOPE_PACKAGES_DIR=${NORTHSLOPE_DIR}/packages
mkdir -p ${NORTHSLOPE_PACKAGES_DIR}

#------------------------------------------------------------------------------
# Permissions Check
#------------------------------------------------------------------------------

# Check write permissions for files we'll modify
TOOL="file permissions"
print_check_msg "${TOOL}"

# Keep an array of permission errors
PERMISSION_ERRORS=()
BAD_PERMISSION_PATHS=()

# Check NORTHSLOPE_DIR separately (directory)
if [[ ! -d "$NORTHSLOPE_DIR" ]]; then
    PERMISSION_ERRORS+=("Northslope directory uncreatable at: $NORTHSLOPE_DIR")
    BAD_PERMISSION_PATHS+=("$(dirname "$NORTHSLOPE_DIR")")
else
    # Directory exists, try to chown to verify permissions
    chown "$USER" "$NORTHSLOPE_DIR" 2>/dev/null
    if [[ $? -ne 0 ]] || [[ ! -w "$NORTHSLOPE_DIR" ]]; then
        PERMISSION_ERRORS+=("No write permission for directory: $NORTHSLOPE_DIR")
        BAD_PERMISSION_PATHS+=("$NORTHSLOPE_DIR")
    fi
fi

# Check RC files and git config
FILES_TO_CHECK=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.gitconfig"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [[ -e "$file" ]]; then
        # File exists, try to chown to verify permissions
        chown "$USER" "$file" 2>/dev/null
        if [[ $? -ne 0 ]] || [[ ! -w "$file" ]]; then
            PERMISSION_ERRORS+=("No write permission for file: $file")
            BAD_PERMISSION_PATHS+=("$file")
        fi
    else
        # File doesn't exist, try to create it
        touch "$file" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            PERMISSION_ERRORS+=("Cannot create file: $file")
            BAD_PERMISSION_PATHS+=("$(dirname "$file")")
        fi
    fi
done

if [[ ${#PERMISSION_ERRORS[@]} -gt 0 ]]; then
    echo "Permission Errors Detected 🚫"
    echo ""
    echo "The following permission issues were found:"
    for error in "${PERMISSION_ERRORS[@]}"; do
        echo "  ❌ $error"
    done
    print_failed_install_msg "${TOOL}" "Permission errors detected: ${BAD_PERMISSION_PATHS[*]}" 1 "system" ""
    echo ""
    echo "Please fix these permission issues before running setup again by running the following:"
    echo ""
    for f in "${BAD_PERMISSION_PATHS[@]}"; do
        echo "sudo chown $USER $f"
    done
    exit 1
else
    print_and_record_already_installed_msg "${TOOL}" "" "system"
fi

#------------------------------------------------------------------------------
# Parse NS CLI Branch options
#------------------------------------------------------------------------------

NS_CLI_BRANCH="$1"


#------------------------------------------------------------------------------
# Shell Setup
#------------------------------------------------------------------------------

NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH=${NORTHSLOPE_DIR}/setup-version

NORTHSLOPE_SETUP_SCRIPT_PATH=${NORTHSLOPE_DIR}/northslope-setup.sh
NORTHSLOPE_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-base-shell.rc
NORTHSLOPE_STYLE_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-style-shell.rc
NORTHSLOPE_UTILITY_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-utility-shell.rc

NORTHSLOPE_STARSHIP_CONFIG_PATH=${NORTHSLOPE_DIR}/starship.toml

NORTHSLOPE_DOWNLOADABLE_PATHS=(
    ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    ${NORTHSLOPE_SHELL_RC_PATH}
    ${NORTHSLOPE_UTILITY_SHELL_RC_PATH}
    ${NORTHSLOPE_STYLE_SHELL_RC_PATH}

    ${NORTHSLOPE_STARSHIP_CONFIG_PATH}
)
NORTHSLOPE_SHELL_RC_PATHS=(${NORTHSLOPE_SHELL_RC_PATH} ${NORTHSLOPE_UTILITY_SHELL_RC_PATH} ${NORTHSLOPE_STYLE_SHELL_RC_PATH})
NORTHSLOPE_ADDED_TAG="# Added by Northslope"

# Manage both bashrc and zshrc
TARGET_SHELL_RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc")
for shell_rc in "${TARGET_SHELL_RC_FILES[@]}"; do
    # Create the shell rc file if it doesn't exist
    touch "$shell_rc"
done

#------------------------------------------------------------------------------
# Shell Setup: Remove Old Shell RC Setup
#------------------------------------------------------------------------------

OLD_NORTHSLOPE_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-shell.rc
OLD_NORTHSLOPE_STARSHIP_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-starship-shell.rc
OLD_SCRIPTS=($OLD_NORTHSLOPE_SHELL_RC_PATH $OLD_NORTHSLOPE_STARSHIP_SHELL_RC_PATH)

# Clean up old shell RC references from shell config files
for shell_rc in "${TARGET_SHELL_RC_FILES[@]}"; do
    # Make a backup copy
    rm -f "${shell_rc}.northslope.bak"
    cp "${shell_rc}" "${shell_rc}.northslope.bak"
    if [[ -f "$shell_rc" ]]; then
        for old_script in "${OLD_SCRIPTS[@]}"; do
            # Remove old script path if exists
            if grep -q "source ${old_script}" "$shell_rc"; then
                grep -v "source ${old_script}" "$shell_rc" > "${shell_rc}.northslope.tmp"
                cat "${shell_rc}.northslope.tmp" > "$shell_rc"
            fi
        done

        # Remove old Northslope header if exists
        if grep -q "^# Added by Northslope" "${shell_rc}"; then
            grep -v "^# Added by Northslope" "${shell_rc}" > "${shell_rc}.northslope.tmp"
            cat "${shell_rc}.northslope.tmp" > "$shell_rc"
        fi

        # Remove non-tagged script path if exists
        for northslope_shell_rc_path in "${NORTHSLOPE_SHELL_RC_PATHS[@]}"; do
            if grep -q "source ${northslope_shell_rc_path}$" "$shell_rc"; then
                grep -v "source ${northslope_shell_rc_path}$" "$shell_rc" > "${shell_rc}.northslope.tmp"
                cat "${shell_rc}.northslope.tmp" > "$shell_rc"
            fi
        done
    fi
done

for old_script in "${OLD_SCRIPTS[@]}"; do
    rm -f "${old_script}"
done

#------------------------------------------------------------------------------
# Shell Setup: Add Northslope configs
#------------------------------------------------------------------------------
for shell_rc in "${TARGET_SHELL_RC_FILES[@]}"; do
    for northslope_shell_rc_path in "${NORTHSLOPE_SHELL_RC_PATHS[@]}"; do
        shell_name=$(basename "$shell_rc")
        shell_rc_name=$(basename ${northslope_shell_rc_path})
        grep "source ${northslope_shell_rc_path} ${NORTHSLOPE_ADDED_TAG}" "$shell_rc" > /dev/null 2>&1
        northslope_rc_in_shell=$?
        if [[ ${northslope_rc_in_shell} -ne 0 ]]; then
            echo "source ${northslope_shell_rc_path} ${NORTHSLOPE_ADDED_TAG}" >> "$shell_rc"
        fi
    done
done

function download_latest_shell {
    pids=()
    for northslope_downloadable_path in "${NORTHSLOPE_DOWNLOADABLE_PATHS[@]}"; do
        filename=$(basename ${northslope_downloadable_path})
        url=https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/${filename}
        curl -fsSL ${url} > ${northslope_downloadable_path} &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait ${pid} || return 1
    done
    chmod +x ${NORTHSLOPE_SETUP_SCRIPT_PATH}
    get_latest_version > ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}
}

# Install or upgrade setup script
TOOL="shell commands"
print_check_msg ${TOOL}

any_missing_files=1
for northslope_downloadable_path in "${NORTHSLOPE_DOWNLOADABLE_PATHS[@]}"; do
    if [[ ! -e ${northslope_downloadable_path} ]]; then
        any_missing_files=0
    fi
done

if [[ ! -e ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH} || ${any_missing_files} -eq 0 ]]; then
    print_missing_msg ${TOOL}
    download_latest_shell
    if [[ $? -ne 0 ]]; then
        print_failed_install_msg "${TOOL}" "Failed to download shell files" 1 "manual" ""
        exit 1
    fi
    print_and_record_newly_installed_msg "${TOOL}" "`get_latest_version`"
else
    IS_UPGRADING=1
    current_version=`cat ${NORTHSLOPE_SETUP_SCRIPT_VERSION_PATH}`
    if [[ "${current_version}" != "`get_latest_version`" ]]; then
        IS_UPGRADING=0
    fi
    if [[ ${IS_UPGRADING} -eq 0 ]]; then
        download_latest_shell
        if [[ $? -ne 0 ]]; then
            print_failed_install_msg "${TOOL}" "Failed to download shell files during upgrade" 1 "manual" ""
            exit 1
        fi
        print_and_record_upgraded_msg "${TOOL}" `get_latest_version`
    else
        print_and_record_already_installed_msg "${TOOL}" `get_latest_version`
    fi
fi

#------------------------------------------------------------------------------
# Package Managers
#------------------------------------------------------------------------------

# Install Brew
TOOL=brew
print_check_msg ${TOOL}
brew --help > /dev/null 2>&1
BREW_ALREADY_INSTALLED=$?
if [[ ${BREW_ALREADY_INSTALLED} -ne 0 ]]; then
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

# Verify brew is working after installation
brew_error=$(brew --help 2>&1)
brew_exit_code=$?
if [[ ${brew_exit_code} -ne 0 ]]; then
    print_failed_install_msg "${TOOL}" "Brew installation failed or is not in PATH: ${brew_error}" ${brew_exit_code} "brew" ""
    echo "Cannot go on without brew. Please contact @tnguyen."
    exit 1
else
    BREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "")
    if [[ ${BREW_ALREADY_INSTALLED} -eq 0 ]]; then
        print_and_record_already_installed_msg "${TOOL}" ${BREW_VERSION} "brew"
    else
        print_and_record_newly_installed_msg "${TOOL}" ${BREW_VERSION} "brew"
    fi
fi


brew_tools=(
    "asdf__3"
    "autojump__2"
    "fzf__1"
    "starship__2"
    "tree__2"
)

for brew_tool in ${brew_tools[@]}; do
    tool=${brew_tool%__*}
    version_index=${brew_tool#*__}
    brew_install_tool "${tool}" ${version_index}
done

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

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
    print_and_record_newly_installed_msg "${TOOL}" ${GIT_VERSION}
else
    print_and_record_already_installed_msg "${TOOL}" ${GIT_VERSION}
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
    print_and_record_newly_installed_msg "${TOOL}" ${GIT_VERSION}
else
    print_and_record_already_installed_msg "${TOOL}" ${GIT_VERSION}
fi

# Check for git config push.autoSetupRemote
TOOL="git config push.autoSetupRemote"
print_check_msg ${TOOL}
git config --global push.autoSetupRemote | grep "true" > /dev/null 2>&1
GIT_PUSH_ALREADY_SET=$?
if [[ ${GIT_PUSH_ALREADY_SET} -ne 0 ]]; then
    print_missing_msg ${TOOL}
    git config --global push.autoSetupRemote true
    print_and_record_newly_installed_msg "${TOOL}" ${GIT_VERSION}
else
    print_and_record_already_installed_msg "${TOOL}" ${GIT_VERSION}
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
    print_and_record_newly_installed_msg "${TOOL}" ${CURSOR_VERSION} "brew"
else
    CURSOR_VERSION=$(plutil -p /Applications/Cursor.app/Contents/Info.plist 2>/dev/null | grep CFBundleShortVersionString | awk -F'"' '{print $4}' || echo "")
    print_and_record_already_installed_msg "${TOOL}" ${CURSOR_VERSION} "brew"
fi

# Install claude code
brew_install_tool "claude" 2 "--cask" "claude-code"

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

for asdf_tool in "${asdf_tools[@]}"; do
    tool=${asdf_tool%__*}
    version=${asdf_tool#*__}
    asdf_install_and_set "${tool}" ${version}
done
asdf reshim

#------------------------------------------------------------------------------
# Shell Utility
#------------------------------------------------------------------------------

ZSH_SYNTAX_HIGHLIGHTING_DIR=${NORTHSLOPE_PACKAGES_DIR}/zsh-syntax-highlighting
TOOL="zsh-syntax-highlighting"
print_check_msg "${TOOL}"
if [[ -d "${ZSH_SYNTAX_HIGHLIGHTING_DIR}" ]]; then
    print_and_record_already_installed_msg "${TOOL}" "" "git"
else
    print_missing_msg "${TOOL}"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_SYNTAX_HIGHLIGHTING_DIR} > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        print_and_record_newly_installed_msg "${TOOL}" "" "git"
    else
        print_failed_install_msg "${TOOL}" "git clone failed" 1 "git" ""
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
        print_and_record_newly_installed_msg "${TOOL}" ${GH_VERSION} "gh"
    else
        print_failed_install_msg "${TOOL}" "gh auth login failed or was interrupted" ${gh_auth_status} "system" "${GH_VERSION}"
    fi
else
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}' || echo "")
    print_and_record_already_installed_msg "${TOOL}" ${GH_VERSION} "gh"
fi

# Ensure a part of the northslopetech organization
TOOL="github northslopetech org"
print_check_msg "${TOOL}"
gh org list | grep northslopetech > /dev/null 2>&1
GH_IN_NORTHSLOPE_ORG=$?
if [[ ${GH_IN_NORTHSLOPE_ORG} -ne 0 ]]; then
    print_missing_msg "${TOOL}"
    echo ""
    echo "⚠️ You are not a member of the northslopetech organization on Github."
    echo "   If you do not have an invitation, please contact Tam Nguyen (@tnguyen) to be added to the organization."
    echo "   Press enter to check if you have an invitation for the organization. Return here when you have accepted it."
    read
    open 'https://github.com/orgs/northslopetech/invitation'
    echo  ""
    echo "   Press enter to continue setup after accepting the invitation (or not)."
    echo "   If you did not have an invitation, please contact Tam Nguyen (@tnguyen) to be added to the organization."
    read
    gh org list | grep northslopetech > /dev/null 2>&1
    GH_IN_NORTHSLOPE_ORG=$?
    if [[ ${GH_IN_NORTHSLOPE_ORG} -ne 0 ]]; then
        print_failed_install_msg "${TOOL}" "Not a member of northslopetech organization" 1 "gh" ""
    else
        print_and_record_newly_installed_msg "${TOOL}" "" "gh"
    fi
else
    print_and_record_already_installed_msg "${TOOL}" "" "gh"
fi

#------------------------------------------------------------------------------
# Northslope Tools
#------------------------------------------------------------------------------

# Install the ns-cli using the deployed npm package
# unless a specific branch is requested, in which case
# we build and deploy a local version from that branch
TOOL="ns-cli"
if [[ "${NS_CLI_BRANCH}" == "" ]]; then
    # Install ns-cli from npm
    print_check_msg "${TOOL}"
    ns --version > /dev/null 2>&1
    NS_CLI_ALREADY_INSTALLED=$?
    CURR_NS_CLI_VERSION=""
    if [[ ${NS_CLI_ALREADY_INSTALLED} -eq 0 ]]; then
        CURR_NS_CLI_VERSION=$(ns --version 2>/dev/null | awk '{print $1}' || echo "")
    fi

    # Check latest version from npm registry
    LATEST_NS_CLI_VERSION=$(npm view @northslopetech/ns-cli version 2>/dev/null || echo "")

    # Only install if not installed or if version differs
    if [[ ${NS_CLI_ALREADY_INSTALLED} -ne 0 ]] || [[ "${CURR_NS_CLI_VERSION}" != "${LATEST_NS_CLI_VERSION}" ]]; then
        if [[ ${NS_CLI_ALREADY_INSTALLED} -ne 0 ]]; then
            print_missing_msg "${TOOL}"
        fi
        install_output=$(npm install -g @northslopetech/ns-cli 2>&1)
        install_status=$?
        if [[ ${install_status} -eq 0 ]]; then
            NEW_NS_CLI_VERSION=$(ns --version 2>/dev/null | awk '{print $1}' || echo "")
            if [[ ${NS_CLI_ALREADY_INSTALLED} -eq 0 ]]; then
                print_and_record_upgraded_msg "${TOOL}" ${NEW_NS_CLI_VERSION} "npm"
            else
                print_and_record_newly_installed_msg "${TOOL}" ${NEW_NS_CLI_VERSION} "npm"
            fi
        else
            print_failed_install_msg "${TOOL}" "npm install failed: ${install_output}" ${install_status} "npm" ""
        fi
    else
        # Already installed and up to date
        print_and_record_already_installed_msg "${TOOL}" ${CURR_NS_CLI_VERSION} "npm"
    fi
else
    print_check_msg "${TOOL}:${NS_CLI_BRANCH}"
    LOCAL_NS_CLI_DIR=${NORTHSLOPE_PACKAGES_DIR}/ns-cli

    # Create a log file for this installation
    NS_CLI_INSTALL_LOG="${NORTHSLOPE_DIR}/ns-cli-install.log"
    echo "" > ${NS_CLI_INSTALL_LOG}  # Clear/create the log file

    echo "npm uninstall -g ns-cli" >> ${NS_CLI_INSTALL_LOG} 2>&1
    npm uninstall -g ns-cli >> ${NS_CLI_INSTALL_LOG} 2>&1

    echo "asdf which ns" >> ${NS_CLI_INSTALL_LOG} 2>&1
    asdf which ns >> ${NS_CLI_INSTALL_LOG} 2>&1

    current_ns_cli_path=`asdf which ns 2>/dev/null`
    if [[ "${current_ns_cli_path}" != "" ]]; then
        echo "rm \"${current_ns_cli_path}\"" >> ${NS_CLI_INSTALL_LOG} 2>&1
        rm "${current_ns_cli_path}"  >> ${NS_CLI_INSTALL_LOG} 2>&1
    fi

    # Flag to track if we should proceed with installation
    should_install=1
    failed_step=""

    # Clone repository if it doesn't exist
    if [[ ! -e ${LOCAL_NS_CLI_DIR} ]]; then
        echo "$ gh repo clone northslopetech/ns-cli ${LOCAL_NS_CLI_DIR}" >> ${NS_CLI_INSTALL_LOG}
        gh repo clone northslopetech/ns-cli ${LOCAL_NS_CLI_DIR} >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="gh repo clone"
        fi
    fi

    echo "$ cd ${LOCAL_NS_CLI_DIR}" >> ${NS_CLI_INSTALL_LOG}
    cd ${LOCAL_NS_CLI_DIR} >> ${NS_CLI_INSTALL_LOG} 2>&1

    # Fetch the specified branch
    if [[ ${should_install} -eq 1 ]]; then
        echo "$ git checkout main" >> ${NS_CLI_INSTALL_LOG}
        git checkout main >> ${NS_CLI_INSTALL_LOG} 2>&1
        echo "$ git fetch --all" >> ${NS_CLI_INSTALL_LOG}
        git fetch --all >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="git fetch --all"
        fi
    fi

    # Checkout the specified branch
    if [[ ${should_install} -eq 1 ]]; then
        echo "$ git checkout origin/${NS_CLI_BRANCH}" >> ${NS_CLI_INSTALL_LOG}
        git checkout origin/${NS_CLI_BRANCH} >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="git checkout origin/${NS_CLI_BRANCH}"
        fi
    fi

    # Install dependencies
    if [[ ${should_install} -eq 1 ]]; then
        echo "$ rm -rf ${LOCAL_NS_CLI_DIR}/node_modules" >> ${NS_CLI_INSTALL_LOG}
        rm -rf ${LOCAL_NS_CLI_DIR}/node_modules >> ${NS_CLI_INSTALL_LOG} 2>&1
        echo "$ pnpm install --frozen-lockfile" >> ${NS_CLI_INSTALL_LOG}
        pnpm install --frozen-lockfile >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="pnpm install --frozen-lockfile"
        fi
    fi

    # Build the package
    if [[ ${should_install} -eq 1 ]]; then
        echo "$ pnpm build" >> ${NS_CLI_INSTALL_LOG}
        pnpm build >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="pnpm build"
        fi
    fi

    # Link the package globally
    if [[ ${should_install} -eq 1 ]]; then
        echo "$ npm link" >> ${NS_CLI_INSTALL_LOG}
        npm link >> ${NS_CLI_INSTALL_LOG} 2>&1
        if [[ $? -ne 0 ]]; then
            should_install=0
            failed_step="npm link"
        fi
    fi

    if [[ ${should_install} -eq 1 ]]; then
        print_and_record_newly_installed_msg "${TOOL}:${NS_CLI_BRANCH}" "${NS_CLI_BRANCH}" "manual"
    else
        log_contents=$(cat ${NS_CLI_INSTALL_LOG})
        print_failed_install_msg "${TOOL}:${NS_CLI_BRANCH}" "${failed_step} failed. Log: ${log_contents}" 1 "manual" "${NS_CLI_BRANCH}"
    fi

    cd - > /dev/null 2>&1
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
