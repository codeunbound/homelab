# WireGuard Setup

This directory contains a script to automate the setup of a WireGuard VPN server.

## Scripts

- `wireguard-setup.sh`: This script downloads and runs the official WireGuard installation script with a pre-configured set of environment variables for a typical homelab setup.

## Usage

1.  Review the `.env` file created by the script to ensure the variables are correct for your environment.
2.  Run the script: `bash wireguard-setup.sh`

## Installation
```bash
curl -sO https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/wireguard/wireguard-setup.sh
chmod +x wireguard-setup.sh
sudo ./wireguard-setup.sh
```

**Note:** Always review scripts from the internet before running them on your system.

---

## Attribution

The `wireguard-setup.sh` script is based on the excellent work by angristan: [https://github.com/angristan/wireguard-install](https://github.com/angristan/wireguard-install)