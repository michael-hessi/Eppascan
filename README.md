# Eppascan
Automated Integration of Epson Network Scanners with Paperless-NGX

Description:
Eppascan is an automated solution for seamless integration of Epson network scanners with Paperless-NGX. The system consists of two components:

- eppascan.sh:
  A daemon script running on a Linux server that continuously listens for Epson scanner broadcasts on the local network. When a scan is triggered on the scanner, the script detects the device, optionally waits for initialization, starts an automatic duplex scan of all pages in the Automatic Document Feeder (ADF), and saves the scans directly to the Paperless consume directory (/opt/paperless/consume). Status and error messages are logged with timestamps.

- eppascan-install.sh:
  An installation script that installs required packages and dependencies, copies the main script to the appropriate location, sets up the systemd service, and configures permissions. This ensures the scan service runs automatically in the background after system startup.

With Eppascan, scan operations are integrated directly and efficiently into the Paperless workflow - without manual steps or additional software.

---

Usage Instructions:

Please note that after pressing the scan button on the Epson scanner, it takes about 15 seconds before the actual scanning starts. Please be patient!

Typical workflow:
1. Load paper into the ADF.
2. The scanner wakes up; WLAN indicators light up.
3. Press the scan button.
4. The orange exclamation mark on the scanner lights briefly and then turns off.
5. Only then does the scan start, automatically feeding all pages through the ADF.

Reason for delay:
After pressing the scan button, the scanner searches for the original Epson Scan 2 software on the network. Since this solution does not use that software, the scanner waits briefly before proceeding with the alternative scan process. This delay is normal and expected.

---

Configuration:

The default wait time in the script is 15 seconds. If scans do not start reliably (e.g., the scanner is not ready after waking), you can increase the SCAN_INITIAL_DELAY value in the script accordingly.

---

Requirements:

- Epson network scanner (tested with ES-500WII; other network-capable models may work)
- Linux server (Debian/Ubuntu recommended; tested on Proxmox LXC/CT)
- Paperless-NGX installed and configured (/opt/paperless/consume must exist and be writable)
- Network access between scanner and server (same subnet, multicast allowed)
- Root privileges (as typical for Proxmox UserHelperScripts)

---

Installation:

1. Download the installation package:

   wget https://hessburg.de/wp-content/_downloads/eppascan.tar.xz -O /tmp/eppascan.tar.xz

2. Extract and prepare the installer:

   tar -xJvf /tmp/eppascan.tar.xz -C /tmp/
   cd /tmp/eppascan
   chmod +x eppascan_install.sh

3. Run the installer:

   ./eppascan_install.sh

The installer will:
- Install required packages (tcpdump, sane-utils)
- Copy the main script to /usr/local/bin/
- Create and enable the systemd service
- Set appropriate permissions

After installation, the service runs automatically in the background and starts on every reboot.

---

Configuration options:

Key variables in eppascan.sh can be adjusted before installation:

| Variable          | Description                        | Example Value               |
|-------------------|----------------------------------|----------------------------|
| NETWORK_INTERFACE  | Server's network interface        | eth0                       |
| MULTICAST_ADDR    | Epson scanner multicast address   | 239.255.255.253            |
| SCAN_OUTPUT_DIR   | Scan output directory (Paperless) | /opt/paperless/consume     |
| SCAN_RESOLUTION   | Scan resolution in dpi             | 300                        |
| SCAN_MODE         | Scan mode (Color, Gray, Lineart)  | Grey                       |
| SCAN_FORMAT       | Output file format                 | jpeg                       |

For optimal OCR results, a resolution of at least 300 dpi and grayscale mode is recommended.

---

Troubleshooting:

- Check the eppascan log for errors:

  tail -n 50 /var/log/eppascan_scanimage_errors.log

- Verify network multicast traffic with:

  tcpdump -i eth0 igmp

- Ensure firewall rules allow UDP 3289, UDP 3702, TCP 1865, and TCP 445.

- Confirm scanner and server are on the same subnet.

- Test SANE backend with:

  scanimage -L

- Verify permissions of /opt/paperless/consume:

  chown -R paperless:paperless /opt/paperless/consume

- Check Paperless consumer logs:

  journalctl -u paperless-consumer -f

---

Uninstallation:

Run the installer script again and select the uninstall option.

---

License:

This project is licensed under the GNU General Public License (GPL). See the LICENSE file for details.

---

References:

- ProxmoxVE UserHelperScripts: Paperless-NGX
- Paperless-NGX Scanner Documentation
- Epson Port Configuration
- SANE epsonds Backend
