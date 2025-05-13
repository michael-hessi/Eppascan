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
# License: GNU GPLv3 or later – see <http://www.gnu.org/licenses/>.

set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---

NETWORK_INTERFACE="eth0"
MULTICAST_ADDR="239.255.255.253"
SCAN_INITIAL_DELAY=15
SCAN_TIMEOUT=300
SCAN_RESOLUTION="300"
SCAN_MODE="Gray"
SCAN_FORMAT="jpeg"
SCAN_OUTPUT_DIR="/opt/paperless/consume"
LOGFILE="/var/log/eppascan_scanimage_errors.log"

# --- Logging ---
log_eppascan() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] [EPPASCAN] $*" >> "$LOGFILE"
}

# --- Temp file & cleanup ---
TMP_TCPDUMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_TCPDUMP_OUTPUT"; log_eppascan "Script terminated."; exit 0' SIGINT SIGTERM EXIT

log_eppascan "Script started. Listening on $NETWORK_INTERFACE for Epson scanner broadcasts."

# --- Main loop ---
while true; do
    : > "$TMP_TCPDUMP_OUTPUT"  # Clear the file using ':' (no-op)

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

        SCAN_FILENAME_BASE="scan_$(date +'%Y%m%d_%H%M%S')"
        SCAN_FULLPATH_PATTERN="$SCAN_OUTPUT_DIR/${SCAN_FILENAME_BASE}_%04d.$SCAN_FORMAT"

        log_eppascan "Starting scan to $SCAN_FULLPATH_PATTERN."

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
