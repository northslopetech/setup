NORTHSLOPE_DIR=${HOME}/.northslope
TARGET_SHELL_RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc")
NORTHSLOPE_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-base-shell.rc
NORTHSLOPE_STARSHIP_SHELL_RC_PATH=${NORTHSLOPE_DIR}/northslope-starship-shell.rc
NORTHSLOPE_SHELL_RC_PATHS=(${NORTHSLOPE_SHELL_RC_PATH} ${NORTHSLOPE_STARSHIP_SHELL_RC_PATH})
NORTHSLOPE_ADDED_TAG="# Added by Northslope"
set -x

# BODY

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
            rm -f "${old_script}"
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
