That's a good idea\! Many users find `curl` to be a more common and direct utility for downloading content from the command line.

I'll update the `README.md` to use the `curl` command for the download steps, replacing `wget`. I'll also use `curl -o` for clarity, which explicitly names the output file.

Here is the updated `README.md`.

-----

# Proxmox CIFS Auto-Mount and Dynamic IP Updater

This script is designed for a Proxmox host that utilizes a TrueNAS (or other SMB/CIFS server) running as a virtual machine. It ensures that your CIFS shares are correctly configured and mounted, even if the TrueNAS VM's IP address changes or if the VM starts slowly after the Proxmox host reboots.

### Key Features

  * **Dynamic IP Fetching**: When using the VMID option, the script automatically uses the QEMU Guest Agent to retrieve the VM's current IP address.
  * **Systemd Unit Update**: If the TrueNAS IP address has changed, the script automatically updates the path in the corresponding `/etc/systemd/system/*.mount` files.
  * **Idempotent Mounting**: The script checks if shares are mounted and only attempts to mount them if they are currently unmounted.
  * **External Script Persistence**: The necessary `get-vm-ip.sh` utility is downloaded only once to `/root/scripts/` and reused on subsequent runs.

-----

## ⚙️ Setup and Installation

### Prerequisites

1.  **QEMU Guest Agent**: Must be installed and running on your TrueNAS VM (or the VM specified by the VMID).
2.  **Required Utilities (on Proxmox Host)**: `jq`, `curl`, and `getopt` must be installed.
3.  **CIFS Credentials**: A credential file (`/root/.smbcredentials`) must exist for your CIFS mounts. *Note: This script assumes your existing mount units reference this file.*
4.  **Existing Mount Units**: This script assumes you have corresponding systemd mount units (`/etc/systemd/system/mnt-tank-*.mount`) that need dynamic IP updating.

### Installation Steps (Recommended)

1.  **Download and Execute Permissions**: Navigate to a suitable location (e.g., `/root/scripts/`) and download the script using `curl`.

    ```bash
    # Download the script to your desired location (e.g., /root/)
    curl -o check_and_mount_shares.sh "https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/nas/check_and_mount_shares.sh"

    # Make it executable
    chmod +x check_and_mount_shares.sh
    ```

2.  **Initial Run**: Execute the script once using the appropriate command (see Usage below) to download the auxiliary `get-vm-ip.sh` script and verify functionality.

-----

## 💻 Usage

The script requires **exactly one** argument to specify the TrueNAS host.

```bash
# General Usage Syntax
./check_and_mount_shares.sh -c "<Mount_PATHS>" (-v <VMID> | --vmid <VMID>) | (-i <IP_ADDRESS> | --ip <IP_ADDRESS>)
```

### Execution Methods

| Option | Argument Type | Example Command | Description |
| :--- | :--- | :--- | :--- |
| **-v, --vmid** | Proxmox VMID (Number) | `./check_and_mount_shares.sh -v 156` | Uses `get-vm-ip.sh` to dynamically fetch the IP from the VMID. **Recommended.** |
| **-i, --ip** | IPv4 Address | `./check_and_mount_shares.sh --ip 192.168.1.6` | Uses a static IP address directly. Skips the dynamic IP fetching logic. |

### One-Time Execution via `curl` (Testing Only)

You can run the script without saving it, but note that this is not suitable for deployment as a cron job or systemd service:

```bash
curl -s "https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/nas/check_and_mount_shares.sh" | bash -s -- -i <IP> -c "/mnt/tank/data_share"
```

-----

## 🧩 Integration (Systemd/Cron)

This script is ideal for running as a **systemd timer** or **cron job** on the Proxmox host to periodically check and correct mount status.

### Systemd Timer Example (Recommended)

To run the script every 5 minutes:

1.  **Create the Service Unit** (`/etc/systemd/system/truenas-mount-checker.service`):

    ```ini
    [Unit]
    Description=TrueNAS Mount and IP Checker Service
    Requires=network-online.target
    After=network-online.target

    [Service]
    Type=oneshot
    # IMPORTANT: Update the path and the -v <VMID> argument
    ExecStart=/root/check_and_mount_shares.sh -v 156
    User=root
    Group=root
    StandardOutput=journal
    ```

2.  **Create the Timer Unit** (`/etc/systemd/system/truenas-mount-checker.timer`):

    ```ini
    [Unit]
    Description=Runs TrueNAS Mount Checker every 5 minutes

    [Timer]
    OnBootSec=1min
    OnUnitActiveSec=5min

    [Install]
    WantedBy=timers.target
    ```

3.  **Enable and Start the Timer**:

    ```bash
    systemctl daemon-reload
    systemctl enable truenas-mount-checker.timer
    systemctl start truenas-mount-checker.timer
    ```

    *You can check the timer status with `systemctl status truenas-mount-checker.timer`.*
