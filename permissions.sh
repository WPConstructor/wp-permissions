#!/usr/bin/env bash
#
# WPConstructor Permissions
# Copyright (c) 2026 WPConstructor
#
# Licensed under the MIT License.
# You may obtain a copy of the License at:
# https://opensource.org/licenses/MIT
#
# This software is provided "AS IS", without warranty of any kind,
# express or implied. See the LICENSE file for the full license text.
#
# WordPress Shared Permissions Manager
#
# Configures shared read/write access for:
#   - The current Linux user
#   - The web server user (Apache/PHP)
#
# Features:
#   - Automatic owner detection
#   - Web server user validation
#   - Persistent configuration
#   - Shared Linux group
#   - Directory and file permissions
#   - Default ACLs for newly created files
#
# Usage:
#   chmod +x set-wp-permissions.sh
#   sudo ./set-wp-permissions.sh /path/to/wordpress
#

set -Eeuo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/wp-permissions.conf"

# --------------------------------------------------
# Root check
# --------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Please run this script with sudo."
    echo "Usage: sudo $0 /path/to/wordpress"
    exit 1
fi

# --------------------------------------------------
# Target directory
# --------------------------------------------------

TARGET="${1:-}"

if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
    echo "Usage: sudo $0 /path/to/wordpress"
    exit 1
fi

TARGET="$(realpath "$TARGET")"

# --------------------------------------------------
# Load configuration
# --------------------------------------------------

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Loading configuration..."

    # Configuration must be trusted because it is sourced.
    source "$CONFIG_FILE"
else
    echo "Creating initial configuration..."

    OWNER=""
    WEBUSER="daemon"
    SHARED_GROUP="wp-shared"
fi

# --------------------------------------------------
# Detect owner automatically
# --------------------------------------------------

OWNER="${OWNER:-${SUDO_USER:-}}"

if [[ -z "$OWNER" ]]; then
    echo "ERROR: Could not detect the original user."
    exit 1
fi

if ! id "$OWNER" &>/dev/null; then
    echo "ERROR: User '$OWNER' does not exist."
    exit 1
fi

# --------------------------------------------------
# Validate web server user
# --------------------------------------------------

if [[ -z "${WEBUSER:-}" ]] || ! id "$WEBUSER" &>/dev/null; then

    echo
    echo "Web server user '${WEBUSER:-}' does not exist."
    echo

    while true; do
        read -rp "Enter web server username: " INPUT_USER

        if [[ -n "$INPUT_USER" ]] && id "$INPUT_USER" &>/dev/null; then
            WEBUSER="$INPUT_USER"
            break
        fi

        echo "Invalid username. Please try again."
    done
fi

# --------------------------------------------------
# Validate shared group
# --------------------------------------------------

SHARED_GROUP="${SHARED_GROUP:-wp-shared}"

if ! getent group "$SHARED_GROUP" >/dev/null; then
    echo "Creating shared group: $SHARED_GROUP"
    groupadd "$SHARED_GROUP"
fi

# --------------------------------------------------
# Save configuration
# --------------------------------------------------

TMP_CONFIG="$(mktemp "$SCRIPT_DIR/.wp-permissions.conf.XXXXXX")"

cat > "$TMP_CONFIG" <<EOF
# WordPress shared permissions configuration

OWNER="$OWNER"
WEBUSER="$WEBUSER"
SHARED_GROUP="$SHARED_GROUP"
EOF

chmod 600 "$TMP_CONFIG"
mv -f "$TMP_CONFIG" "$CONFIG_FILE"

echo
echo "Configuration saved."
echo "Owner:  $OWNER"
echo "Web:    $WEBUSER"
echo "Group:  $SHARED_GROUP"

# --------------------------------------------------
# Add users to shared group
# --------------------------------------------------

echo
echo "Adding users to shared group..."

usermod -aG "$SHARED_GROUP" "$OWNER"
usermod -aG "$SHARED_GROUP" "$WEBUSER"

# --------------------------------------------------
# Set ownership
# --------------------------------------------------

echo
echo "Setting ownership..."

chown -R "$OWNER:$SHARED_GROUP" "$TARGET"

# --------------------------------------------------
# Set directory permissions
# --------------------------------------------------

echo "Setting directory permissions..."

find "$TARGET" -type d -exec chmod 2770 {} +

# --------------------------------------------------
# Set file permissions
# --------------------------------------------------

echo "Setting file permissions..."

find "$TARGET" -type f -exec chmod 0660 {} +

# --------------------------------------------------
# Configure ACLs
# --------------------------------------------------

if command -v setfacl >/dev/null 2>&1; then

    echo "Configuring ACL permissions..."

    # Existing files and directories
    setfacl -R \
        -m "u:$OWNER:rwX,u:$WEBUSER:rwX,g:$SHARED_GROUP:rwX,m:rwX" \
        "$TARGET"

    # Default ACLs for newly created files and directories
    find "$TARGET" -type d -exec \
        setfacl -m \
        "d:u:$OWNER:rwX,d:u:$WEBUSER:rwX,d:g:$SHARED_GROUP:rwX,d:m:rwX" \
        {} +

else

    echo
    echo "WARNING: setfacl is not installed."
    echo "Install the ACL package for additional access control."
fi

# --------------------------------------------------
# Finished
# --------------------------------------------------

echo
echo "============================================"
echo " WordPress permissions configured!"
echo "============================================"
echo
echo "Target:  $TARGET"
echo "Owner:   $OWNER"
echo "Webuser: $WEBUSER"
echo "Group:   $SHARED_GROUP"
echo
echo "Directories: 2770"
echo "Files:       0660"
echo
echo "Configuration: $CONFIG_FILE"
echo
echo "NOTE: New group membership requires a new login"
echo "session or service restart to take effect."
echo