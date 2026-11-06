#!/usr/bin/env bash
#
# WPConstructor WP Permissions
# Copyright (c) 2026 WPConstructor
#
# Licensed under the MIT License.
# https://opensource.org/licenses/MIT
#
# This software is provided "AS IS", without warranty of any kind.
# See the LICENSE file for the full license text.
#

set -Eeuo pipefail

# ============================================================
# WPConstructor WP Permissions
# ============================================================

VERSION="0.1.0"

DEFAULT_WEBUSER="daemon"
DEFAULT_GROUP="wp-shared"

# ============================================================
# Resolve Script Location
# ============================================================

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname -- "$SCRIPT_PATH")"

CONFIG_FILE="$SCRIPT_DIR/wp-permissions.conf"

# ============================================================
# Default Configuration
# ============================================================

OWNER=""
WEBUSER="$DEFAULT_WEBUSER"
SHARED_GROUP="$DEFAULT_GROUP"

# ============================================================
# Colors
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# Output Functions
# ============================================================

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

# ============================================================
# Validation
# ============================================================

validate_name() {
    [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ ]]
}

validate_user() {
    validate_name "$1" && id "$1" >/dev/null 2>&1
}

validate_group() {
    validate_name "$1"
}

# ============================================================
# Root Check
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    die "Please run this script using sudo."
fi

# ============================================================
# Dependencies
# ============================================================

for command in \
    readlink realpath find chown chmod \
    groupadd usermod getent id mktemp
do
    command -v "$command" >/dev/null 2>&1 ||
        die "Required command not found: $command"
done

# ============================================================
# Usage
# ============================================================

if [[ "${1:-}" == "--version" ]]; then
    echo "WPConstructor WP Permissions $VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" ]]; then

    echo
    echo "WPConstructor WP Permissions $VERSION"
    echo
    echo "Usage:"
    echo "  sudo wp-permissions /path/to/wordpress"
    echo
    echo "Options:"
    echo "  --help       Display help"
    echo "  --version    Display version"
    echo
    exit 0

fi

if [[ $# -ne 1 ]]; then

    echo
    echo "Usage:"
    echo "  sudo wp-permissions /path/to/wordpress"
    echo
    exit 1

fi

# ============================================================
# Target Directory
# ============================================================

[[ -d "$1" ]] || die "Target directory does not exist."

TARGET="$(realpath -e -- "$1")"

[[ -d "$TARGET" ]] || die "Invalid target directory."

# Refuse dangerous system directories.

case "$TARGET" in
    /|/home|/root|/etc|/usr|/var|/opt|/tmp|/boot|/proc|/sys|/dev)
        die "Refusing to modify a protected system directory."
        ;;
esac

# ============================================================
# WordPress Detection
# ============================================================

if [[ ! -f "$TARGET/wp-config.php" ]] &&
   [[ ! -d "$TARGET/wp-admin" || ! -d "$TARGET/wp-includes" ]]; then

    die "The target does not appear to be a WordPress installation."

fi

# ============================================================
# Load Configuration Safely
# ============================================================

if [[ -L "$CONFIG_FILE" ]]; then
    die "Configuration file must not be a symbolic link."
fi

if [[ -e "$CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
    die "Configuration path is not a regular file."
fi

if [[ -f "$CONFIG_FILE" ]]; then

    info "Loading configuration..."

    while IFS= read -r line || [[ -n "$line" ]]; do

        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^OWNER=\"([^\"]*)\"$ ]]; then

            OWNER="${BASH_REMATCH[1]}"

        elif [[ "$line" =~ ^WEBUSER=\"([^\"]*)\"$ ]]; then

            WEBUSER="${BASH_REMATCH[1]}"

        elif [[ "$line" =~ ^SHARED_GROUP=\"([^\"]*)\"$ ]]; then

            SHARED_GROUP="${BASH_REMATCH[1]}"

        else

            die "Invalid entry in configuration file: $line"

        fi

    done < "$CONFIG_FILE"

else

    info "No configuration file found. Creating one."

fi

# ============================================================
# Detect Linux Owner
# ============================================================

OWNER="${OWNER:-${SUDO_USER:-}}"

if [[ -z "$OWNER" ]]; then
    die "Unable to detect your Linux username."
fi

validate_user "$OWNER" ||
    die "Invalid or non-existing Linux user: $OWNER"

[[ "$OWNER" != "root" ]] ||
    die "Root cannot be used as the file owner."

success "Linux owner: $OWNER"

# ============================================================
# Validate Web Server User
# ============================================================

if ! validate_user "$WEBUSER"; then

    warning "Configured web server user does not exist: $WEBUSER"

    while true; do

        read -r -p "Enter Apache/PHP username: " INPUT_WEBUSER

        if validate_user "$INPUT_WEBUSER"; then

            WEBUSER="$INPUT_WEBUSER"
            break

        fi

        error "Invalid or non-existing Linux user."

    done

else

    echo
    info "Configured web server user: $WEBUSER"

    read -r -p "Use this account? [Y/n]: " ANSWER

    if [[ "$ANSWER" =~ ^[Nn]$ ]]; then

        while true; do

            read -r -p "Enter Apache/PHP username: " INPUT_WEBUSER

            if validate_user "$INPUT_WEBUSER"; then

                WEBUSER="$INPUT_WEBUSER"
                break

            fi

            error "Invalid or non-existing Linux user."

        done

    fi

fi

success "Web server user: $WEBUSER"

# ============================================================
# Validate Shared Group
# ============================================================

validate_group "$SHARED_GROUP" ||
    die "Invalid shared group name."

# ============================================================
# Create Shared Group
# ============================================================

if ! getent group "$SHARED_GROUP" >/dev/null 2>&1; then

    info "Creating shared group: $SHARED_GROUP"

    groupadd "$SHARED_GROUP" ||
        die "Unable to create shared group."

else

    info "Shared group already exists."

fi

success "Shared group ready."

# ============================================================
# Save Configuration
# ============================================================

info "Saving configuration..."

TEMP_CONFIG="$(mktemp "$SCRIPT_DIR/.wp-permissions.XXXXXX")"

cleanup() {
    [[ -n "${TEMP_CONFIG:-}" && -f "$TEMP_CONFIG" ]] &&
        rm -f -- "$TEMP_CONFIG"
}

trap cleanup EXIT

cat > "$TEMP_CONFIG" <<EOF
# WPConstructor WP Permissions
# Configuration file

OWNER="$OWNER"
WEBUSER="$WEBUSER"
SHARED_GROUP="$SHARED_GROUP"
EOF

chmod 600 "$TEMP_CONFIG"
chown "$OWNER" "$TEMP_CONFIG"

mv -f -- "$TEMP_CONFIG" "$CONFIG_FILE"

TEMP_CONFIG=""

success "Configuration saved."

# ============================================================
# Add Users to Shared Group
# ============================================================

add_user_to_group() {

    local USER="$1"

    if id -nG "$USER" | tr ' ' '\n' |
        grep -Fxq "$SHARED_GROUP"; then

        info "$USER is already a member of $SHARED_GROUP."

    else

        info "Adding $USER to $SHARED_GROUP..."

        usermod -aG "$SHARED_GROUP" "$USER" ||
            die "Unable to add $USER to shared group."

        success "$USER added to shared group."

    fi
}

add_user_to_group "$OWNER"

if [[ "$WEBUSER" != "$OWNER" ]]; then
    add_user_to_group "$WEBUSER"
fi

# ============================================================
# Confirm Changes
# ============================================================

echo
echo "============================================================"
echo "WPConstructor WP Permissions"
echo "============================================================"
echo
echo "Target directory : $TARGET"
echo "Linux owner      : $OWNER"
echo "Web server user  : $WEBUSER"
echo "Shared group     : $SHARED_GROUP"
echo
warning "Ownership and permissions will be changed recursively."
warning "Mounted filesystems below the target will be skipped."
echo

read -r -p "Continue? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then

    warning "Operation cancelled."
    exit 0

fi

# ============================================================
# Configure Ownership
# ============================================================

info "Configuring ownership..."

find "$TARGET" -xdev -exec \
    chown -h -- "$OWNER:$SHARED_GROUP" {} + ||
    die "Unable to configure ownership."

success "Ownership configured."

# ============================================================
# Configure Directory Permissions
# ============================================================

info "Configuring directory permissions..."

find "$TARGET" -xdev -type d -exec \
    chmod 2770 {} + ||
    die "Unable to configure directory permissions."

success "Directory permissions configured."

# ============================================================
# Configure Regular Files
# ============================================================

info "Configuring file permissions..."

# Non-executable files.

find "$TARGET" -xdev -type f ! -perm /111 -exec \
    chmod 0660 {} + ||
    die "Unable to configure regular files."

# Executable files.
# Preserve executable status while restricting access for others.

find "$TARGET" -xdev -type f -perm /111 -exec \
    chmod u+rw,g+rw,o-rwx,g+x {} + ||
    die "Unable to configure executable files."

success "File permissions configured."

# ============================================================
# Configure ACLs
# ============================================================

if command -v setfacl >/dev/null 2>&1; then

    info "Configuring Access Control Lists..."

    find "$TARGET" -xdev -exec \
        setfacl -m \
        "u:$OWNER:rwX,u:$WEBUSER:rwX,g:$SHARED_GROUP:rwX,m:rwX" \
        {} + ||
        die "Unable to configure ACL permissions."

    # Default ACLs for new files and directories.

    find "$TARGET" -xdev -type d -exec \
        setfacl -m \
        "d:u:$OWNER:rwx,d:u:$WEBUSER:rwx,d:g:$SHARED_GROUP:rwx,d:m:rwx" \
        {} + ||
        die "Unable to configure default ACL permissions."

    success "ACL permissions configured."

else

    warning "setfacl is not installed."
    warning "Continuing with standard Linux permissions."

fi

# ============================================================
# Completion
# ============================================================

echo
echo "============================================================"
success "WPConstructor WP Permissions completed!"
echo "============================================================"
echo
echo "Version          : $VERSION"
echo "Target           : $TARGET"
echo "Linux owner      : $OWNER"
echo "Web server user  : $WEBUSER"
echo "Shared group     : $SHARED_GROUP"
echo "Configuration    : $CONFIG_FILE"
echo

warning "New group membership requires a new login session."
warning "Restart Apache/XAMPP if necessary."

echo
echo "XAMPP restart:"
echo "sudo /opt/lampp/lampp restart"
echo
echo "Check group membership:"
echo "groups $OWNER"
echo "groups $WEBUSER"
echo
echo "Check directory permissions:"
echo "ls -ld \"$TARGET\""
echo
echo "Check ACL permissions:"
echo "getfacl \"$TARGET\""
echo