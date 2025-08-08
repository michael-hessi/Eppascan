#!/usr/bin/env bash

# Eppascan - Epson Scanner Integration for Paperless-NGX, v0.1
#
# Ein Dienst für einen headless Paperless-NGX Server, der auf den Scan-Knopf
# eines Netzwerk-Epson-Scanners wartet und dann automatisch scannt und die
# Dokumente in das Paperless consume Verzeichnis legt.
#
# Lauscht auf Epson Scanner Broadcasts und scannt alle Seiten
# nach /opt/paperless/consume
#
# Copyright (C) 2025 Michael Hessburg, www.hessburg.de
# Lizenz: GNU GPLv3 oder höher - siehe <http://www.gnu.org/licenses/>.

set -euo pipefail
IFS=$'\n\t'

# --- Konfiguration ---

NETWORK_INTERFACE="eth0"
# MULTICAST_ADDR ist hier nicht mehr relevant, könnte bei Bedarf erhalten bleiben
SCAN_INITIAL_DELAY=15
SCAN_TIMEOUT=300
SCAN_RESOLUTION="300"
SCAN_MODE="Gray"
#
SCAN_FORMAT="jpeg"
SCAN_OUTPUT_DIR="/opt/paperless/consume"
LOGFILE="/var/log/eppascan_scanimage_errors.log"

# --- Logging-Funktion ---
log_eppascan() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] [EPPASCAN] $*" >> "$LOGFILE"
}

# --- Temp-Datei & Cleanup ---
TMP_TCPDUMP_OUTPUT=$(mktemp)
trap 'rm -f "$TMP_TCPDUMP_OUTPUT"; log_eppascan "Script terminated."; exit 0' SIGINT SIGTERM EXIT

log_eppascan "Script started. Listening on $NETWORK_INTERFACE for Epson scanner broadcasts."

# --- Hauptloop ---
while true; do
    : > "$TMP_TCPDUMP_OUTPUT" # Leere Datei

    DETECTED_IP=""

    # TCPDump lauscht auf genau ein IGMP-Paket ohne DNS-Auflösung (IP-Adressen)
    if ! tcpdump -n -q -c 1 -i "$NETWORK_INTERFACE" igmp > "$TMP_TCPDUMP_OUTPUT" 2>/dev/null; then
        log_eppascan "Warning: tcpdump failed on interface $NETWORK_INTERFACE."
        sleep 5
        continue
    fi

    # Debug-Ausgabe vom tcpdump Inhalt ins Log
    log_eppascan "tcpdump output:"
    while IFS= read -r line; do
        log_eppascan "  $line"
    done < "$TMP_TCPDUMP_OUTPUT"

    # --- Gelockerte IGMP-Prüfung ---
    if ! grep -q "igmp" "$TMP_TCPDUMP_OUTPUT"; then
        log_eppascan "No IGMP packet found. Retrying..."
        sleep 2
        continue
    fi

    # IP-Erkennung: alle IPs rausfiltern, keine spezielle Multicast-Adresse ausschließen,
    # aber falls notwendig kannst du sie hier optional ausschließen
    DETECTED_IP=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$TMP_TCPDUMP_OUTPUT" | grep -v "^239\.255\.255\.253$" | head -n1 || true)

    if [[ -z "$DETECTED_IP" ]]; then
        log_eppascan "No valid scanner IP found in tcpdump output. Retrying..."
        sleep 2
        continue
    fi

    log_eppascan "Detected scanner at $DETECTED_IP."

    log_eppascan "Waiting $SCAN_INITIAL_DELAY seconds for scanner initialisation."
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
done
