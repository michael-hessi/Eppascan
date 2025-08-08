#!/usr/bin/env bash

# Eppascan - Epson Scanner Integration for Paperless-NGX, v0.2
#
# A service for a headless Paperless-NGX server that waits for the scan button
# on a network Epson scanner and automatically scans,
# saving documents to the Paperless consume directory.
#
# Listens for Epson scanner broadcasts and scans all pages
# to /opt/paperless/consume
#
# Copyright (C) 2025 Michael Hessburg, www.hessburg.de
# License: GNU GPLv3 or later - see <http://www.gnu.org/licenses/>.

set -euo pipefail
IFS=$'\n\t'

# --- Auto-detect active network interface with IPv4 address ---
detect_network_interface() {
  # Try to get interface used for the default route
  local iface
  iface=$(ip route | awk '/default/ {print $5; exit}')
  if [[ -n "$iface" ]] && ip addr show "$iface" | grep -q "inet "; then
    echo "$iface"
    return
  fi

  # Fallback: first active interface with IPv4 except lo
  local active_iface
  active_iface=$(ip -o -4 addr show up scope global | awk '{print $2}' | grep -v "^lo$" | head -n1)
  if [[ -n "$active_iface" ]]; then
    echo "$active_iface"
    return
  fi

  # Last fallback: eth0 if available
  if ip addr show eth0 >/dev/null 2>&1; then
    echo "eth0"
    return
  fi

  # Nothing found
  echo ""
}

# Set network interface dynamically
NETWORK_INTERFACE=$(detect_network_interface)

# Log file path
LOGFILE="/var/log/eppascan_scanimage_errors.log"

# Logging function
log_eppascan() {
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] [EPPASCAN] $*" >> "$LOGFILE"
}

if [[ -z "$NETWORK_INTERFACE" ]]; then
  log_eppascan "Error: No active network interface found!"
  exit 1
fi

log_eppascan "Detected active network interface: $NETWORK_INTERFACE"

# --- Configuration ---

SCAN_INITIAL_DELAY=15
SCAN_TIMEOUT=300
SCAN_RESOLUTION="300"
SCAN_MODE="Gray"
SCAN_FORMAT="jpeg"
SCAN_OUTPUT_DIR="/opt/paperless/consume"

# --- Temp file & cleanup ---
TMP_TCPDUMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_TCPDUMP_OUTPUT"; log_eppascan "Script terminated."; exit 0' SIGINT SIGTERM EXIT

log_eppascan "Script started. Listening on $NETWORK_INTERFACE for Epson scanner broadcasts."

# --- Main loop ---
while true; do
  : > "$TMP_TCPDUMP_OUTPUT"  # Clear temp file

  DETECTED_IP=""

  # Listen for exactly one IGMP packet without DNS resolution (only IPs)
  if ! tcpdump -n -q -c 1 -i "$NETWORK_INTERFACE" igmp > "$TMP_TCPDUMP_OUTPUT" 2>/dev/null; then
    log_eppascan "Warning: tcpdump failed on interface $NETWORK_INTERFACE."
    sleep 5
    continue
  fi

  # Log tcpdump output
  log_eppascan "tcpdump output:"
  while IFS= read -r line; do
    log_eppascan "  $line"
  done < "$TMP_TCPDUMP_OUTPUT"

  # Check if IGMP packet present
  if ! grep -q "igmp" "$TMP_TCPDUMP_OUTPUT"; then
    log_eppascan "No IGMP packet found. Retrying..."
    sleep 2
    continue
  fi

  # Extract IP addresses and exclude known multicast address optionally
  DETECTED_IP=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$TMP_TCPDUMP_OUTPUT" | grep -v "^239\.255\.255\.253$" | head -n1 || true)

  if [[ -z "$DETECTED_IP" ]]; then
    log_eppascan "No valid scanner IP found in tcpdump output. Retrying..."
    sleep 2
    continue
  fi

  log_eppascan "Scanner detected at IP $DETECTED_IP."

  log_eppascan "Waiting $SCAN_INITIAL_DELAY seconds for scanner initialization."
  sleep "$SCAN_INITIAL_DELAY"

  SCAN_FILENAME_BASE="scan_$(date +'%Y%m%d_%H%M%S')"
  SCAN_FULLPATH_PATTERN="$SCAN_OUTPUT_DIR/${SCAN_FILENAME_BASE}_%04d.$SCAN_FORMAT"

  log_eppascan "Starting scan, saving to $SCAN_FULLPATH_PATTERN."

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
done
