#!/bin/bash

# --- ⚙️ Configuration ---

# Define the permanent location for the IP retrieval script
LOCAL_SCRIPT_PATH="$HOME/scripts/get-vm-ip.sh"
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/nas/get-vm-ip.sh"

# Initialize Array
SHARE_CONFIG=( )

# Global variables to store argument choice
INPUT_TYPE="" # Can be "vmid" or "ip"
INPUT_VALUE="" # The VMID or IP provided as argument
TRUENAS_IP="" # The final IP address used for mounting

# --- 🛠️ Helper Functions ---

# Function to display usage instructions
usage() {
    echo "Usage: $0 -c \"<MOUNT_PATH>\" (-v <VMID> | --vmid <VMID>) | (-i <IP_ADDRESS> | --ip <IP_ADDRESS>)"
    echo "  -c, --config \"<MOUNT_PATH>\"     : Comma seprated mount path ending with share directory (e.g., /mnt/tank/path1)."
    echo "  -v, --vmid <VMID>                   : The Proxmox VMID of the TrueNAS server (e.g., 156)."
    echo "  -i, --ip <IP_ADDRESS>               : The static IP address of the TrueNAS server (e.g., 192.168.1.6)."
    echo ""
    echo "Error: You must provide exactly one option and its corresponding value."
    exit 1
}

# Function to parse command-line arguments using getopt
parse_args() {
    # 1. Define options: Short options 'v' and 'i' both require an argument (colon).
    #    Long options 'vmid' and 'ip' also require an argument (= sign).
    OPTS=$(getopt -o v:i:c: --long vmid:,ip:,config: --name "$0" -- "$@")

    if [ $? -ne 0 ]; then
        usage
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -c|--config)
                # Check if value exists
                if [[ -n "$2" && "$2" != -* ]]; then
                    RAW_INPUT="$2"
                    
                    # 1. Temporarily set IFS to comma to split the string
                    # 2. read -ra splits the string into the ADDR array
                    # 3. '<<<' passes the string into read
                    IFS=',' read -ra ADDR <<< "$RAW_INPUT"
                    
                    # Add the split items to the main configuration array
                    for path in "${ADDR[@]}"; do
                        SHARE_CONFIG+=("$path")
                    done
                    
                    shift # Shift past the flag (-c)
                    shift # Shift past the value
                else
                    echo "Error: Argument for $1 is missing."
                    exit 1
                fi
                ;;
            -v|--vmid)
                # Check for duplicate options
                if [ -n "$INPUT_TYPE" ]; then usage; fi
                
                # Check if argument is a number (VMID)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    INPUT_TYPE="vmid"
                    INPUT_VALUE="$2"
                else
                    echo "Error: Invalid VMID '$2'. Must be a number." >&2
                    usage
                fi
                shift 2
                ;;
            -i|--ip)
                # Check for duplicate options
                if [ -n "$INPUT_TYPE" ]; then usage; fi
                
                # Check if argument is an IP address
                if [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    INPUT_TYPE="ip"
                    INPUT_VALUE="$2"
                else
                    echo "Error: Invalid IP address '$2'. Must be a valid IPv4 address." >&2
                    usage
                fi
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                # Should not happen if getopt is used correctly, but catch-all
                usage
                ;;
        esac
    done

    # Check that exactly one option was provided
    if [ -z "$INPUT_TYPE" ]; then
        usage
    fi

    echo "Using ${INPUT_TYPE^^}: $INPUT_VALUE"
}

# Function to fetch the VM's IP address based on input type, reusing the script if available
get_truenas_ip() {
    
    if [ "$INPUT_TYPE" == "ip" ]; then
        # If IP was provided, use it directly
        TRUENAS_IP="$INPUT_VALUE"
        return 0
    fi
    
    # --- Dynamic fetching logic (only runs if VMID was chosen) ---

    echo "Attempting to retrieve IP for VMID $INPUT_VALUE using external script..."
    
    # 1. Check if the script needs to be downloaded
    if [ ! -f "$LOCAL_SCRIPT_PATH" ]; then
        echo "Script not found at $LOCAL_SCRIPT_PATH. Downloading from GitHub..."
        mkdir -p $HOME/scripts # Ensure the target directory exists

        # Fetch the script using curl
        if ! curl -fsSL "$GITHUB_SCRIPT_URL" -o "$LOCAL_SCRIPT_PATH"; then
            echo "🔴 Error: Failed to download the IP retrieval script from $GITHUB_SCRIPT_URL." >&2
            return 1
        fi
        
        # Make the script executable
        chmod +x "$LOCAL_SCRIPT_PATH"
        echo "✅ Script downloaded and saved locally."
    else
        echo "Script found locally. Reusing $LOCAL_SCRIPT_PATH."
    fi

    # 2. Execute the local script and capture the output
    SCRIPT_OUTPUT=$("$LOCAL_SCRIPT_PATH" "$INPUT_VALUE")
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo "🔴 Error running the local IP script (Exit Code $EXIT_CODE):" >&2
        echo "$SCRIPT_OUTPUT" >&2
        return 1
    fi

    # 3. Parse the successful output (e.g., "✅ IP Address(es) for VMID 156: 192.168.1.6")
    IP_ADDRESSES=$(echo "$SCRIPT_OUTPUT" | /usr/bin/awk '/✅ IP Address/{print $NF}')
    
    if [ -z "$IP_ADDRESSES" ]; then
        echo "🔴 Local IP script ran successfully but returned no usable IP address." >&2
        echo "   Full script output: $SCRIPT_OUTPUT" >&2
        return 1
    fi

    TRUENAS_IP="$IP_ADDRESSES"
    return 0
}

# Function to update the systemd mount unit with the new IP
update_mount_unit_ip() {
    local MOUNT_POINT="$1"
    local TARGET_IP="$2"

    local MOUNT_UNIT=$(/usr/bin/basename "$MOUNT_POINT" | /usr/bin/sed 's/^/mnt-tank-/')
    local MOUNT_UNIT_PATH="/etc/systemd/system/${MOUNT_UNIT}.mount"

    # Construct the full, desired CIFS path (e.g., //192.168.1.8/media)
    local SHARE_NAME=$(/usr/bin/basename "$MOUNT_POINT")
    local NEW_PATH="//${TARGET_IP}/${SHARE_NAME}"

    if [[ ! -f "$MOUNT_UNIT_PATH" ]]; then
        echo "INFO: Mount unit file not found: $MOUNT_UNIT_PATH" >&2

        cat <<EOF > $MOUNT_UNIT_PATH
[Unit]
Description=CIFS Mount for TrueNAS Media Share
Requires=network-online.target
After=network-online.target

[Mount]
What=$NEW_PATH
Where=$MOUNT_POINT
Type=cifs
Options=credentials=$HOME/.smbcredentials,_netdev,x-systemd.automount,noatime,uid=100999,gid=100991,dir_mode=0777,file_mode=0777

[Install]
# WantedBy=multi-user.target
EOF
    else
        # 1. Check if the line already matches the desired path
        if /usr/bin/grep -q "^What=${NEW_PATH}$" "$MOUNT_UNIT_PATH"; then
            echo "➡️ IP check for $MOUNT_UNIT: IP is already correct ($NEW_PATH). No change needed."
            return 0
        fi

        # 2. Substitution: Find the line starting with 'What=' and replace the entire line
        echo "🚨 What= line corrupted or changed for $MOUNT_UNIT. Forcing update to: ${NEW_PATH}..."

        # Use sed to find the line starting with 'What=' and replace the entire line with the new, correct line.
        /usr/bin/sed -i "/^What=/c\What=${NEW_PATH}" "$MOUNT_UNIT_PATH"
    fi

    if [[ $? -eq 0 ]]; then
        echo "✅ IP/PATH UPDATE SUCCESS: Reloading systemd daemon..."
        /usr/bin/systemctl daemon-reload
        return 0
    else
        echo "🔴 IP/PATH UPDATE FAILURE: Failed to update line in $MOUNT_UNIT_PATH. Check file permissions." >&2
        return 1
    fi
}

# Function to check if a directory is mounted
is_mounted() {
    local MOUNT_POINT="$1"
    if /usr/bin/grep -q " ${MOUNT_POINT} " /proc/mounts; then
        return 0 # Mounted
    else
        return 1 # Not mounted
    fi
}

# --- 🚀 Main Logic ---
echo "--- $(/usr/bin/date) --- Starting mount check and dynamic IP update."

# 1. Parse and validate arguments
parse_args "$@"

# 2. Get the TrueNAS IP address (either from argument or script)
get_truenas_ip

if [ $? -ne 0 ] || [ -z "$TRUENAS_IP" ]; then
    echo "❌ Failed to retrieve TrueNAS IP. Aborting mount checks."
    exit 1
fi

echo "🟢 Target TrueNAS IP: $TRUENAS_IP"

# 3. Loop through all configured shares
for MOUNT_POINT in "${SHARE_CONFIG[@]}"; do
    
    # 3a. Update the systemd mount unit with the retrieved IP
    update_mount_unit_ip "$MOUNT_POINT" "$TRUENAS_IP"

    # 3b. Check mount status and attempt mount if not mounted
    if is_mounted "$MOUNT_POINT"; then
        echo "✅ $MOUNT_POINT is already mounted."
    else
        echo "⚠️ $MOUNT_POINT is NOT mounted. Attempting to mount..."

        MOUNT_UNIT=$(/usr/bin/basename "$MOUNT_POINT" | /usr/bin/sed 's/^/mnt-tank-/')
        
        /usr/bin/systemctl start "$MOUNT_UNIT".mount

        if is_mounted "$MOUNT_POINT"; then
            echo "🟢 Successfully mounted $MOUNT_POINT."
        else
            echo "🔴 Failed to mount $MOUNT_POINT. Check system logs with 'journalctl -xeu ${MOUNT_UNIT}.mount'."
        fi
    fi
done

echo "Finished mount check and IP update."