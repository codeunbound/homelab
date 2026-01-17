> This repository contains the automation scripts, configuration files, and architecture notes for my personal homelab.
>
> **The Goal:** A one-stop, painless guide to building a production-ready homelab that balances **Performance** (LXC/NVMe) with **Reliability** (TrueNAS/ZFS).

## 📺 Start Here: The Architecture

I document the "Why" and "How" of this setup on YouTube. I move away from monolithic VMs and instead decouple Compute from Storage.
**Latest Video: Access Your Home Lab Anywhere: WireGuard + AWS EC2 Guide (No Fluff)**

[![Watch the Video](https://img.youtube.com/vi/qKlXEZgboFc/maxresdefault.jpg)](https://youtu.be/qKlXEZgboFc)
> *[Click to watch the full walkthrough.](https://youtu.be/qKlXEZgboFc)*
---

## 📂 Project Modules

### 📸 1. Immich (Google Photos Replacement)
**Status:** ✅ Active | [📂 Go to Guide](./proxmox/immich/README.md)
* **The Problem:** Moving 100GB+ of photos to a new install without breaking the Database.
* **The Fix:** A custom `migrate.sh` script.
* **Key Scripts:**
    * [`migrate.sh`](./proxmox/immich/migrate.sh) - Automates data migration & symlinking.

### 🔌 2. Infrastructure & Automation
**Status:** ✅ Active | [📂 Go to Scripts](./automation/nas)
* **The Problem:** NFS/SMB mounts hanging the boot process if the NAS is sleeping.
* **The Fix:** Automation to check share availability before starting services.
* **Key Scripts:**
    * `check_and_mount_shares.sh` - Smart mounting logic.

### 🤖 3. n8n - Immich Auto Heal
**Status:** ✅ Active | [📂 Go to Guide](./proxmox/n8n/README.md)
* **The Problem:** Immich service can go down if the NAS is rebooted or network shares are temporarily unavailable.
* **The Fix:** An n8n workflow that automatically detects if Immich is down, verifies dependencies, and attempts a graceful restart.
* **Key Files:**
    * [`Immich Auto Heal.json`](./proxmox/n8n/Immich%20Auto%20Heal.json) - The n8n workflow template.

### 🌐 4. Access Your Home Lab Anywhere: WireGuard + AWS EC2 Guide (No Fluff)
**Status:** ✅ Active | [📂 Go to Guide](./proxmox/wireguard/README.md)
* **The Problem:** Needing secure, performant remote access to the homelab, bypassing CGNAT.
* **The Fix:** A hub-and-spoke VPN using WireGuard on a free-tier AWS EC2 instance.
* **Key Components:**
    * EC2 Hub Server
    * Proxmox LXC Spoke

---

## 🔮 Coming Soon (Roadmap)
I am actively building and documenting the following stacks. Star the repo to get updates!

* **🎬 Jellyfin Media Server:** Hardware Transcoding (Intel QSV) inside LXC.
* **🏴‍☠️ The *Arr Stack:** Sonarr/Radarr linked to Qbittorrent with VPN kill-switches.
* **🧠 AI/LLM Lab:** Local LLM hosting using the i5-14600K & Dedicated GPU.

---

## 🛠️ Hardware Reference
* **Compute Node:** Intel i5-14600K | 64GB DDR5 | Proxmox VE
* **Storage Node:** TrueNAS Scale | 4x 4TB IronWolf (RAIDZ1)
* **Network:** 10GbE Direct Link

## 🤝 Connect & Contribute
* **YouTube:** [Code Unbound](https://www.youtube.com/@codeunbound)
* **Issues:** Found a bug? Open an issue or submit a PR!

---
*Disclaimer: These scripts are tailored to my environment. Always check paths/IPs before running root scripts on your production machine.*