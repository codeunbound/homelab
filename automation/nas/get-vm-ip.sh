#!/bin/bash

# Script to get the IP address(es) of a Proxmox VM using its VMID
# Requires QEMU Guest Agent to be installed and running in the VM,
# and the 'jq' command-line JSON processor on the Proxmox host.

VMID="$1"

# --- Function to display usage ---
usage() {
    echo "Usage: $0 <VMID>"
    echo "Example: $0 101"
    exit 1
}

# --- Check for VMID argument ---
if [ -z "$VMID" ]; then
    echo "Error: VMID not provided."
    usage
fi

# --- Check if the VM exists and is a KVM (qemu) guest ---
if ! qm status "$VMID" &>/dev/null; then
    echo "Error: VMID $VMID not found or is not a QEMU VM."
    exit 1
fi

# --- Execute the QEMU Guest Agent command and parse the output ---
echo "Attempting to get IP address(es) for VMID $VMID..."

# qm guest cmd sends the 'network-get-interfaces' command to the QEMU Guest Agent.
# **VMID is now correctly passed using the variable $VMID**
IP_ADDRESSES=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null | \
  jq -r '.[ ] | .["ip-addresses"][]? | select(."ip-address-type" == "ipv4") | .["ip-address"]' | \
  grep -v '^127\.' | \
  tr '\n' ' ')

# --- Output the result ---
if [ -z "$IP_ADDRESSES" ]; then
    echo "❌ Could not retrieve IP address(es) for VMID $VMID."
    echo "   Ensure the VM is running and the QEMU Guest Agent is installed and enabled."
else
    echo "✅ IP Address(es) for VMID $VMID: ${IP_ADDRESSES}"
fi

exit 0