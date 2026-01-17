# Access Your Home Lab Anywhere: WireGuard + AWS EC2 Guide (No Fluff)

This guide provides the step-by-step instructions to accompany the YouTube video. We will deploy a WireGuard VPN server on an AWS EC2 instance to act as a central "hub". This allows us to bypass ISP limitations like CGNAT (Carrier-Grade NAT) and create a secure, private network for our homelab and mobile devices.

## Prerequisites

- An AWS (Amazon Web Services) account.
- Basic familiarity with the Linux command line.
- A homelab service (e.g., a Docker/LXC container/VM) that you want to access remotely.

---

## Step 1: Set Up the EC2 "Hub" Server

Our first step is to create the central server that all our devices will connect to.

1.  **Launch an EC2 Instance:**
    *   Log in to your AWS Console and navigate to the EC2 service.
    *   Click "Launch instance".
    *   Give it a name, like `wireguard-hub`.
    *   For the "Amazon Machine Image (AMI)", select **Amazon Linux 2**.
    *   Choose an instance type. The `t2.micro` or `t3.micro` instance is more than sufficient and is eligible for the AWS Free Tier.
    *   Create or select a key pair. You will need this to SSH into your server. Save the `.pem` file securely.

2.  **Configure the Security Group (Firewall):**
    *   In the "Network settings" section, click "Edit".
    *   Create a new security group.
    *   Add the following **inbound rules**:
        *   **Rule 1 (SSH):**
            *   Type: `SSH`
            *   Source type: `My IP` (This is more secure, allowing only you to SSH into the server).
        *   **Rule 2 (WireGuard):**
            *   Type: `Custom UDP`
            *   Port range: `61517` (This is the port specified in our installer script).
            *   Source type: `Anywhere` (0.0.0.0/0).
    *   Launch the instance.

3.  **Run the Installer Script:**
    *   Connect to your new EC2 instance via SSH using the key pair you saved. The command will look something like this:
        ```bash
        ssh -i /path/to/your-key.pem ec2-user@YOUR_EC2_PUBLIC_IP
        ```
    *   Once connected, download the installer script from this project's GitHub repository (Note: The URL will need to be updated to the final repo).
        ```bash
        curl -O https://github.com/codeunbound/homelab/blob/main/automation/wireguard/wireguard-setup.sh
        ```
    *   Make the script executable:
        ```bash
        chmod +x wireguard-setup.sh
        ```
    *   Run the script. It will set up the WireGuard server and create the first client config for your homelab.
        ```bash
        sudo ./wireguard-setup.sh
        ```
    *   Follow the on-screen prompts. The script will handle the installation and configuration.

---

### Crucial Reminder: Set Up an EC2 Budget!

While our `t2.micro` instance is Free Tier eligible, it's *imperative* to set up a billing alarm or budget in your AWS account. This will alert you if your costs exceed a certain threshold, protecting you from unexpected charges if you accidentally exceed Free Tier limits or misconfigure something. We won't cover this process in this guide, but it's a vital step for any cloud deployment.

---

## Step 2: Connect Your Homelab ("Spoke 1") - Using a Proxmox LXC

Now we'll connect your homelab to the hub using a dedicated LXC container in Proxmox. The installer script has already created a client configuration for this, named `homelab01.conf`.

1.  **Retrieve the Homelab Config:**
    *   On your EC2 instance, view the contents of the client config file:
        ```bash
        sudo cat /etc/wireguard/wg0-clients/homelab01.conf
        ```
    *   Copy the entire contents of this file.

2.  **Prepare a Proxmox LXC Container:**
    *   **Create a new LXC Container:**
        *   In Proxmox, create a new LXC container (e.g., using a Debian or Ubuntu template). Assign it sufficient resources (e.g., 512MB RAM, 1 CPU core).
        *   **Crucially, enable `nesting` and `keyctl` features for the LXC** in its Proxmox configuration. This is often done by editing the LXC's config file (`/etc/pve/lxc/<VMID>.conf`) on the Proxmox host to add the following line to grant the container access to the host's TUN device:
            ```yaml
            dev0: /dev/net/tun
            ```
            You may also need to add `features: nesting=1,keyctl=1` in the Proxmox GUI or config file.
    *   **Access the LXC:** SSH into your Proxmox host, then access the LXC console:
        ```bash
        pct enter <VMID>
        ```
        (Replace `<VMID>` with your LXC container's ID).

3.  **Set Up WireGuard in the LXC:**
    *   **Update and Install Dependencies:** Inside the LXC, update packages and install WireGuard and `resolvconf`. `resolvconf` is crucial for managing DNS settings when the tunnel is active.
        ```bash
        apt update && apt upgrade -y
        apt install wireguard-tools resolvconf iptables -y
        ```
        (If using a different base image, use its respective package manager, e.g., `yum install wireguard-tools openresolv iptables -y` for CentOS/Fedora).
    *   **Create `wg0.conf`:** Create the WireGuard configuration file:
        ```bash
        mkdir -p /etc/wireguard
        nano /etc/wireguard/wg0.conf
        ```
    *   **Paste Configuration:** Paste the client configuration you copied from the EC2 instance (from step 1 above) into `/etc/wireguard/wg0.conf`. Save and exit the editor.
    *   **Enable and Start WireGuard:**
        ```bash
        systemctl enable wg-quick@wg0
        systemctl start wg-quick@wg0
        ```
    *   **Verify Connection:** Check the WireGuard status:
        ```bash
        wg show
        ```
        You should see handshake information if connected successfully.

Your homelab LXC is now persistently connected to the EC2 hub.

---

## Step 3: Connect Your Mobile Device ("Spoke 2")

Let's add your phone so you can access your homelab from anywhere.

1.  **Create a New Client Config:**
    *   Connect to your EC2 instance via SSH again.
    *   Run the installer script a second time.
        ```bash
        sudo ./wireguard-setup.sh
        ```
    *   When prompted, choose to **"Add a new client"**.
    *   Give it a descriptive name, like `codeunbound01`.

2.  **Get the QR Code:**
    *   The script may offer to generate a QR code. If not, you can easily generate one yourself. First, you may need to install a tool for this:
        ```bash
        sudo yum install qrencode -y
        ```
    *   Now, generate the QR code directly in your terminal:
        ```bash
        sudo qrencode -t ansiutf8 -r /home/ec2-user/wg0-client-codeunbound01.conf
        ```

3.  **Import to Your Phone:**
    *   Install the official WireGuard app on your Android or iOS device.
    *   Open the app and tap the "+" button.
    *   Choose "Create from QR code" and scan the code displayed in your SSH terminal.
    *   Give the connection a name.
    *   **Crucially, edit the connection and ensure the "AllowedIPs" setting includes your homelab's subnet.** For example, if your homelab is on `192.168.2.0/24`, your `AllowedIPs` should include `192.168.2.0/24`, in addition to the WireGuard server's IP. A setting of `0.0.0.0/0` will route all traffic through the VPN, which is also a valid option.
    *   Toggle the connection on.

---

### Enabling Full Homelab Access (Routing)

A crucial part of this setup is allowing your mobile device (Spoke 2) to access your *entire* homelab network, not just the WireGuard LXC container. To achieve this, we need to configure the WireGuard LXC (Spoke 1) to act as a router for your homelab.

Here's how it works and how to set it up:

1.  **Enable IP Forwarding in the LXC:**
    *   Inside the WireGuard LXC, open the `sysctl.conf` file:
        ```bash
        nano /etc/sysctl.conf
        ```
    *   Uncomment the following line to enable IP forwarding:
        ```
        net.ipv4.ip_forward=1
        ```
    *   Save the file and apply the changes immediately:
        ```bash
        sysctl -p
        ```

2.  **Add Firewall Rules for NAT:**
    *   We need to tell WireGuard to add and remove a Network Address Translation (NAT) rule whenever the VPN connection starts or stops. This makes the LXC "masquerade" traffic coming from your phone, so it appears to originate from the LXC itself, allowing it to reach other devices on your LAN.
    *   Edit the WireGuard configuration file **on the LXC container**:
        ```bash
        nano /etc/wireguard/wg0.conf
        ```
    *   Add the following `PostUp` and `PostDown` lines inside the `[Interface]` section. `eth0` should be the main network interface of your LXC.
```ini
[Interface]
# ... your existing PrivateKey and Address lines ...
PostUp = iptables -A FORWARD -i %i -o eth0 -j ACCEPT
PostUp = iptables -A FORWARD -i eth0 -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -o eth0 -j ACCEPT
PostDown = iptables -D FORWARD -i eth0 -o %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# ...
```
    *   **Important**: Make sure to replace the placeholder `... your existing PrivateKey and Address lines ...` comment with your actual `PrivateKey` and `Address` lines. Do not delete them.
    *   Restart the WireGuard service for the changes to take effect:
        ```bash
        systemctl restart wg-quick@wg0
        ```

With these changes, any traffic from your phone destined for your local network (e.g., `192.168.X.X`) will be correctly forwarded by the WireGuard LXC, giving you seamless access to all your homelab services.

---

## Step 4: Verification

You now have a fully functional private network.

-   **From your phone:** Disconnect from WiFi. With the WireGuard connection active, try to access an internal service in your homelab using its local IP address (e.g., `http://192.168.2.100:2283` for Immich). It should work!
-   **Check Your Public IP:** From your phone, navigate to a site like `ifconfig.me`. It should show the public IP address of your EC2 instance, proving that your traffic is being securely routed through your hub.
