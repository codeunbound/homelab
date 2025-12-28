# Immich on Proxmox LXC (The "Split-Brain" Architecture)

This guide accompanies the **Code Unbound** video tutorial. It details how to deploy Immich in a Proxmox LXC container while splitting the storage architecture: keeping the database on local NVMe for speed and offloading heavy assets (photos/videos) to a NAS or External Drive.

## Prerequisites

* A running Proxmox VE node.
* (Optional) **External Storage:** A NAS (SMB/NFS) OR a External Drive connected to the Proxmox node.
    * Note: You can run Immich purely on local storage, but this guide focuses on the external storage setup for long-term use.*


* (Optional) A dedicated dataset for this project.
    * We use `codeunbound` in this guide, but you can name yours `media`, `photos`, or `immich`.*



---

## Part 1: LXC Deployment

We utilize the Proxmox Helper Scripts to establish the baseline container with hardware acceleration enabled.

1. Open a shell on your Proxmox Node.
2. Run the installer (using `curl`):
```bash
bash -c "$(curl -fsSL https://community-scripts.github.io/ProxmoxVE/scripts?id=immich)"
```


3. **Configuration Settings (Advanced):**
* **Distribution:** Debian 13 (or 12 Bookworm)
* **Cores:** 4 (Required for responsive ML)
* **RAM:** 8192MB (8GB) - *Gives room for heavy timeline scrolling.*
* **Storage:** 20GB (Local Boot Disk)
* **Network:** Static IP Recommended (e.g., `192.168.2.100`)



> **💡 GPU Acceleration Note:**
> The script automatically detected and passed through the **Intel iGPU** (Render/Card devices). This allows Immich to perform hardware-accelerated video transcoding and machine learning without crushing your CPU.

---

## Part 2: Storage Architecture

**Goal:** Map your external storage into the container so we don't fill up the local Proxmox disk. Choose **Option A** (NAS) or **Option B** (External Drive) below.

### Option A: NAS (Network Storage)

#### 1. Configure NAS Credentials

**Important:** Your NAS credentials must be stored securely. Run this on your Proxmox Host:

```bash
cat <<EOF > $HOME/.smbcredentials
username=codeunbound
password=superstrongpassword
domain=WORKGROUP
EOF
chmod 600 $HOME/.smbcredentials

```

*(Replace with your actual NAS username and password)*

#### 2. Mount NAS to Proxmox Host

We use a specific set of mount options to ensure the **Unprivileged LXC** (which maps `root` to a high UID on the host) can actually write to the share.

**The Magic Options (For Reference):**

```text
Options=credentials=$HOME/.smbcredentials,_netdev,x-systemd.automount,noatime,uid=100999,gid=100991,dir_mode=0777,file_mode=0777

```

**Running the Automation Script:**
This script automatically applies these specific flags for you.

> **Note:** In the command below, we use the share name `/codeunbound`. If you named your dataset `photos` or `media`, update the path accordingly (e.g., `/mnt/tank/photos`).

```bash
curl -s "https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/nas/check_and_mount_shares.sh" | bash -s -- -i <YOUR_NAS_IP> -c "/mnt/tank/codeunbound"

```

* **`-i`**: The IP address of your NAS.
* **`-c`**: The target mount path on the Proxmox Host.

---

### Option B: Direct Attached Storage (USB / External HDD)

If you are plugging a drive directly into the Proxmox node, we use a **Systemd Service** to ensure it mounts reliably on boot with the correct permissions for the unprivileged container.

#### 1. Identify your Disk UUID

Plug in the drive and find its UUID (e.g., `1234-ABCD`):

```bash
lsblk -f
```

#### 2. Create the Systemd Service

Create a new service file:

```bash
nano /etc/systemd/system/immich-usb.service
```

Paste the following content. **Note the `uid/gid` options**: These map the drive so the container (ID 100) can write to it.

```ini
[Unit]
Description=Mount External USB Drive for Immich
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
# Create the mount point if it doesn't exist
ExecStartPre=/usr/bin/mkdir -p /mnt/external_usb
# MOUNT COMMAND: Replace UUID=<YOUR_UUID> with your actual UUID from lsblk
# For NTFS/exFAT drives, use: uid=100000,gid=100000,umask=000
ExecStart=/usr/bin/mount -o noatime,uid=100000,gid=100000,umask=000 UUID=<YOUR_UUID_HERE> /mnt/external_usb
# For EXT4 drives, remove uid/gid/umask above and uncomment the line below to set permissions:
# ExecStartPost=/usr/bin/chown -R 100000:100000 /mnt/external_usb

ExecStop=/usr/bin/umount /mnt/external_usb

[Install]
WantedBy=multi-user.target

```

#### 3. Enable and Start the Service

Reload the systemd daemon to recognize the new file, enable it to start on boot, and start it now.

```bash
systemctl daemon-reload
systemctl enable immich-usb.service
systemctl start immich-usb.service
```

**Verify the mount:**

```bash
ls -l /mnt/external_usb
# You should see the owner is 100000 (or similar high ID), NOT root.
```

---

### 3. Bind Mount to LXC

We need to "punch a hole" from the Host to the Container.

1. Identify your Container ID (e.g., `100`).
2. Edit the LXC configuration file on the **Proxmox Host**:
```bash
vim /etc/pve/lxc/100.conf
```


3. Add the following line to the bottom of the file (Choose the path based on Option A or B):
**For NAS (Option A):**
```text
mp0: /mnt/tank/codeunbound,mp=/mnt/photos
```


*(Note: Replace `/mnt/tank/codeunbound` with your actual dataset path if different)*
**For USB (Option B):**
```text
mp0: /mnt/external_usb,mp=/mnt/photos
```


4. Restart the container:
```bash
pct reboot 100
```



**Validation:**

1. Enter container: `pct enter 100`
2. Check permissions: `ls -la /mnt/photos` (Should be writable)
3. Test write: `touch /mnt/photos/testfile` (Should succeed without error)

---

## Part 3: Data Migration

We use a script to move the default data folders to the NAS/USB mount and create symbolic links.

> **⚠️ CRITICAL WARNING:**
> You must run this script **INSIDE THE LXC CONTAINER** (`pct enter 100`).

1. **Enter the Container Console:**
```bash
pct enter 100
```


2. **Download & Run the Migration Script:**
```bash
curl -O https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/proxmox/immich/migrate.sh
chmod +x migrate.sh
./migrate.sh
```



**What this script does:**

* Stops the Immich stack.
* Moves `library` and `upload` folders to `/mnt/photos`.
* Creates symlinks linking the original locations to the new external path.
* Restarts the stack.

---

## Part 4: Access

Open your browser and navigate to:
`http://192.168.2.100:2283` (or your specific IP)

## References & Credits
* **Original Migration Logic:** based on the discussion in [Proxmox VE Community Scripts #5075](https://github.com/community-scripts/ProxmoxVE/discussions/5075#discussioncomment-14939768).
