# Eppascan
Automated Integration of Epson Network Scanners with Paperless-NGX

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [References](#references)

---

## About

**Eppascan** is an open-source solution for seamless integration of Epson network scanners (tested with ES-500WII) with [Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx). It consists of a daemon script for automated scanning and an installation script for easy setup as a systemd service. Once installed, scan operations triggered on the scanner are automatically detected and scanned documents are saved directly into the Paperless-NGX consume directory.

---

## Features

- Listens for Epson scanner broadcasts on the local network
- Automatically starts duplex scans from the ADF when a scan is triggered
- Saves scanned files directly to `/opt/paperless/consume` for Paperless-NGX processing
- Runs as a systemd service for background operation and autostart
- Detailed logging for status and error diagnosis

---

## Requirements

- Epson network scanner (tested: ES-500WII; others may work)
- Linux server (Debian/Ubuntu recommended)
- [Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx) installed and configured
- Network access between scanner and server (same subnet, multicast enabled)
- Root privileges for installation

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/michael-hessi/Eppascan.git
cd Eppascan
chmod +x eppascan_install.sh
./eppascan_install.sh
```

The installer will:  
- Install required packages (`tcpdump`, `sane-utils`)  
- Copy the main script to `/usr/local/bin/`  
- Create and enable the systemd service  
- Set appropriate permissions  

---

## Configuration

Before installation, you may edit variables in `eppascan.sh` as needed:

| Variable          | Description                      | Example Value             |
|-------------------|----------------------------------|---------------------------|
| `NETWORK_INTERFACE` | Network interface               | `eth0`                    |
| `MULTICAST_ADDR`    | Multicast address               | `239.255.255.253`         |
| `SCAN_OUTPUT_DIR`   | Output directory                | `/opt/paperless/consume`  |
| `SCAN_RESOLUTION`   | Scan resolution (dpi)           | `300`                     |
| `SCAN_MODE`         | Scan mode (Color, Gray, Lineart)| `Gray`                    |
| `SCAN_FORMAT`       | Output file format              | `jpeg`                    |

> 💡 For best OCR results, use at least 300 dpi and grayscale mode.

---

## Usage

1. Load documents into the scanner's ADF.  
2. Wake up the scanner; ensure network connection is active.  
3. Press the scan button.  
4. Wait approximately 15 seconds (the scanner searches for Epson Scan 2 software; this delay is normal).  
5. The scan will start automatically; all pages in the ADF will be processed and saved to `/opt/paperless/consume`.

---

## Troubleshooting

- **Check logs:**  
  ```bash
  tail -n 50 /var/log/eppascan_scanimage_errors.log
  ```

- **Verify multicast traffic:**  
  ```bash
  tcpdump -i eth0 igmp
  ```

- **Check firewall/network:**  
  Ensure UDP ports `3289`, `3702` and TCP ports `1865`, `445` are open.

- **Test SANE backend:**  
  ```bash
  scanimage -L
  ```

- **Check directory permissions:**  
  ```bash
  chown -R paperless:paperless /opt/paperless/consume
  ```

- **Check Paperless logs:**  
  ```bash
  journalctl -u paperless-consumer -f
  ```

If you encounter problems, please open an [issue](https://github.com/michael-hessi/Eppascan/issues) or contact support.

---

## Uninstallation

Run the installer script again and select the uninstall option:

```bash
./eppascan_install.sh
```

---

## Contributing

Contributions, bug reports, and feature requests are welcome!  
Please use [GitHub Issues](https://github.com/michael-hessi/Eppascan/issues) for support and feedback.

---

## License

This project is licensed under the GNU General Public License (GPL).  
See the [LICENSE](LICENSE) file for details.

---

## Contact

- Preferred: [GitHub Issues](https://github.com/michael-hessi/Eppascan/issues)  
- Email: eppascan@hessburg.de

---

## References

- [Paperless-NGX Documentation](https://docs.paperless-ngx.com/)  
- [SANE epsonds Backend](http://www.sane-project.org/man/sane-epsonds.5.html)  
- [Epson Port Configuration](https://epson.com/Support/wa00807)
