#!/usr/bin/env bash

# Eppascan – Epson Scanner Integration for Paperless-NGX, v0.1
#
# A service for a headless Paperless-NGX server that waits for the scan 
# button on any networked Epson scanner to be pressed, to then 
# automatically start a scan process and transfer the documents to the 
# Paperless consume directory.
#
# Listens for Epson scanner broadcast and automatically scans all pages 
# to /opt/paperless/consume
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
IFS=$'\n\t'

# --- Configuration ---

# Network interface to listen on for IGMP packets (e.g., "eth0", "enp3s0")
NETWORK_INTERFACE="eth0"

# Multicast address used by Epson scanners for IGMP broadcast discovery
MULTICAST_ADDR="239.255.255.253"

# Delay (in seconds) after detecting the scanner before starting the scan
# Useful to give the scanner time to initialize after waking up
SCAN_INITIAL_DELAY=15

# Maximum duration (in seconds) allowed for a scan operation before it is forcefully stopped
SCAN_TIMEOUT=300

# Scan resolution in DPI (dots per inch)
# 300 is a good compromise between quality and file size for OCR
SCAN_RESOLUTION="300"

# Scan mode: "Gray" (grayscale), "Color", or "Lineart" (black and white)
# "Gray" is usually sufficient for documents/receipts
SCAN_MODE="Gray"

# Output file format: "jpeg", "tiff", or "png"
# Paperless will later convert these images into PDF/A
SCAN_FORMAT="jpeg"

# Directory where scanned files will be saved
# This should be the Paperless "consume" folder
SCAN_OUTPUT_DIR="/opt/paperless/consume"

# Logfile where all EPPASCAN and scanimage errors and status messages will be written
LOGFILE="/var/log/eppascan_scanimage_errors.log"

# --- Logging function ---
log_eppascan() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] [EPPASCAN] $*" >> "$LOGFILE"
}

# --- Prepare temp file and cleanup ---
TMP_TCPDUMP_OUTPUT=$(mktemp)
trap "rm -f $TMP_TCPDUMP_OUTPUT; log_eppascan 'Script terminated.'; exit 0" SIGINT SIGTERM EXIT

log_eppascan "Script started. Listening on $NETWORK_INTERFACE for Epson scanner broadcasts."

# --- Main loop ---
while true; do
    > "$TMP_TCPDUMP_OUTPUT"
    DETECTED_IP=""

    # Listen for IGMP packet (Epson broadcast)
    if ! tcpdump -i "$NETWORK_INTERFACE" -v igmp -l -c 1 > "$TMP_TCPDUMP_OUTPUT" 2>/dev/null; then
        log_eppascan "Warning: tcpdump failed on interface $NETWORK_INTERFACE."
        sleep 5
        continue
    fi

    # Check for multicast address and extract scanner IP
    if grep -q "$MULTICAST_ADDR" "$TMP_TCPDUMP_OUTPUT"; then
        DETECTED_IP=$(grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' "$TMP_TCPDUMP_OUTPUT" | head -n 1)
        log_eppascan "Detected scanner at $DETECTED_IP."
    else
        sleep 2
        continue
    fi

    if [[ -n "$DETECTED_IP" ]]; then
        log_eppascan "Waiting $SCAN_INITIAL_DELAY seconds for scanner initialization."
        sleep "$SCAN_INITIAL_DELAY"

        # Create a base filename with timestamp for scanned pages
        SCAN_FILENAME_BASE="scan_$(date +'%Y%m%d_%H%M%S')"
        SCAN_FULLPATH_PATTERN="$SCAN_OUTPUT_DIR/${SCAN_FILENAME_BASE}_%04d.$SCAN_FORMAT"

        log_eppascan "Starting scan to $SCAN_FULLPATH_PATTERN."

        # Start batch scan, log only errors from scanimage (with timestamps)
        timeout "${SCAN_TIMEOUT}s" scanimage \
            --device-name="epsonds:net:$DETECTED_IP" \
            --source "ADF Duplex" \
            --resolution "$SCAN_RESOLUTION" \
            --mode "$SCAN_MODE" \
            --format "$SCAN_FORMAT" \
            --batch="$SCAN_FULLPATH_PATTERN" \
            --batch-count -1 \
            1>/dev/null \
            2> >(while read -r line; do log_eppascan "[scanimage] $line"; done) || true

        log_eppascan "Scan process finished (errors, if any, are logged above)."
        sleep 5
    else
        log_eppascan "No scanner IP detected after IGMP packet. Retrying..."
        sleep 2
    fi

    sleep 2
done

