# n8n Workflow Template: Immich Auto-Heal

This repository contains an n8n workflow that acts as a "watchdog" for your Immich server. It automatically detects if the Immich service is down, verifies underlying dependencies (like the NAS and mounts), and attempts to restart the service gracefully.

## How it Works

The workflow runs on a schedule (e.g., every 5 minutes) and performs the following steps:
1.  **Health Check:** Pings the Immich server's health endpoint.
2.  **Dependency Verification:** If Immich is down, it checks if the NAS is online and if the required network share is mounted on the host.
3.  **Graceful Restart:** If all dependencies are healthy, it attempts to stop and then start the Immich container.
4.  **Notifications:** Sends a success or failure notification to a Discord webhook.

## Setup Instructions

To get this workflow running, you'll need to import the `Immich Auto Heal.json` file into your n8n instance and configure a few things.

**1. Global Variables:**

In the n8n editor, find the **"Set Globals"** and **"Set Mount Globals"** nodes and update the following values in the "Value" field:

-   `immich_ip`: The IP address of your Immich server.
-   `nas_ip`: The IP address of your NAS.
-   `mount_path`: The full path to the network mount that Immich uses on the host machine (e.g., `/mnt/photos`).
-   `container_id`: The Proxmox Container ID (e.g., `100`) or Docker container name for your Immich instance.

**2. Credentials:**

When you import this workflow, n8n will show errors on several nodes. Click on each one and create or select the required credential:

-   **Check NAS Health:** Create a new "Bearer Auth" credential with an API key from your TrueNAS (or other NAS) instance.
-   **SSH Nodes (Get Mounts, etc.):** Create a new "SSH Password" or "SSH Key" credential to allow n8n to connect to your Proxmox/Docker host.
-   **Discord Nodes (Success/Failure):** Create a new "Discord Webhook" credential using the webhook URL from your Discord server.

Once configured, set the workflow to "Active" and save it. Your Immich instance is now being monitored!
