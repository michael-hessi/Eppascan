#!/usr/bin/env bash

# Eppascan Installer & Maintenance Script
# Installs, repairs, or uninstalls the Eppascan daemon for Paperless (root only, suitable for LXC)
#
# Copyright (C) 2025 Michael Hessburg, www.hessburg.de
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

set -euo pipefail

# --- Configuration ---
EPPASCAN_SCRIPT="eppascan.sh"                               # Name of the main script in current directory
EPPASCAN_TARGET="/usr/local/bin/eppascan.sh"                # Target path for the script
SERVICE_FILE="/etc/systemd/system/eppascan.service"     # Path for the systemd unit file
LOGFILE="/var/log/eppascan_scanimage_errors.log"        # Log file for Eppascan and scanimage errors

# --- Helper functions ---

# Print info message to terminal
info() {
    echo -e "\033[1;32m[INFO]\033[0m $*"
}

# Print warning message to terminal
warn() {
    echo -e "\033[1;33m[WARN]\033[0m $*"
}

# Print error message to terminal and exit
error() {
    echo -e "\033[1;31m[ERROR]\033[0m $*" >&2
    exit 1
}

# Check if script is run as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
    fi
}

# Check if Eppascan is already installed
check_installed() {
    [[ -f "$EPPASCAN_TARGET" ]] && [[ -f "$SERVICE_FILE" ]]
}

# Install required packages if missing
install_dependencies() {
    info "Checking and installing required packages..."
    PKGS=(tcpdump sane-utils)
    for pkg in "${PKGS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            info "Installing $pkg..."
            apt-get update
            apt-get install -y "$pkg"
        else
            info "$pkg is already installed."
        fi
    done
    # Verify scanimage is available
    if ! command -v scanimage &>/dev/null; then
        error "scanimage not found! Please check your SANE installation."
    fi
}

# Copy Eppascan script to target location
install_script() {
    info "Copying $EPPASCAN_SCRIPT to $EPPASCAN_TARGET..."
    cp "$EPPASCAN_SCRIPT" "$EPPASCAN_TARGET"
    chmod 755 "$EPPASCAN_TARGET"
}

# Ensure logfile exists and is writable
install_logfile() {
    info "Ensuring log file exists and is writable..."
    touch "$LOGFILE"
    chmod 644 "$LOGFILE"
}

# Create systemd service file and start service
install_service() {
    info "Creating systemd service file..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=EPPASCAN Daemon
After=network.target

[Service]
Type=simple
ExecStart=$EPPASCAN_TARGET
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    info "Reloading systemd daemon and enabling service..."
    systemctl daemon-reload
    systemctl enable eppascan.service
    systemctl restart eppascan.service
    info "Systemd service installed and started."
}

# Uninstall EPPASCAN completely
uninstall_all() {
    info "Stopping and disabling service..."
    systemctl stop eppascan.service || true
    systemctl disable eppascan.service || true
    info "Removing systemd service file..."
    rm -f "$SERVICE_FILE"
    info "Removing EPPASCAN script..."
    rm -f "$EPPASCAN_TARGET"
    info "Removing log file..."
    rm -f "$LOGFILE"
    systemctl daemon-reload
    info "EPPASCAN has been completely uninstalled."
}

# Repair existing installation
repair_install() {
    info "Repairing installation..."
    install_dependencies
    install_script
    install_logfile
    install_service
    info "Repair complete."
}

# User menu
main_menu() {
    echo "==============================="
    echo " EPPASCAN Installer/Maintenance "
    echo "==============================="
    if check_installed; then
        echo "EPPASCAN appears to be installed."
        echo "Choose an option:"
        echo "  [d] Uninstall EPPASCAN"
        echo "  [r] Repair/Reinstall EPPASCAN"
        echo "  [q] Quit"
        read -rp "Your choice: " CHOICE
        case "$CHOICE" in
            d|D) uninstall_all ;;
            r|R) repair_install ;;
            *) info "Aborted by user." ;;
        esac
    else
        echo "EPPASCAN is not installed. Starting fresh installation..."
        install_dependencies
        install_script
        install_logfile
        install_service
        info "Installation complete."
    fi
}

# --- Script execution ---

require_root

# Check if main script exists in current directory
if [[ ! -f "$EPPASCAN_SCRIPT" ]]; then
    error "EPPASCAN script $EPPASCAN_SCRIPT not found in current directory!"
fi

main_menu

