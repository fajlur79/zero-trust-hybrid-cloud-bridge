#!/bin/bash

set -euo pipefail

# ==========================================
# Global Constants
# ==========================================
readonly WG_CONF="/etc/wireguard/wg0.conf"
readonly TF_FILE="infra/terraform.tfvars"
readonly WG_IFACE="wg0"
readonly WG_PORT="51820"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# ==========================================
# Helper Functions
# ==========================================
info()  { echo -e "${GREEN}[+] $1${NC}"; }
warn()  { echo -e "${YELLOW}[*] $1${NC}"; }
error() { echo -e "${RED}[-] $1${NC}"; exit 1; }

restart_wg() {
    warn "Restarting WireGuard interface ($WG_IFACE)..."
    sudo wg-quick down "$WG_IFACE" 2>/dev/null || true
    sleep 1
    sudo wg-quick up "$WG_IFACE"
}

# Generate keys and update terraform variables (Used by Option 1 & Option 3)
setup_keys_and_tfvars() {
    warn "Generating WireGuard keys securely in memory..."
    
    LOCAL_PRIV=$(wg genkey)
    LOCAL_PUB=$(echo "$LOCAL_PRIV" | wg pubkey)
    EC2_PRIV=$(wg genkey)
    EC2_PUB=$(echo "$EC2_PRIV" | wg pubkey)

    mkdir -p "$(dirname "$TF_FILE")"
    update_tfvars "ec2_private_key" "$EC2_PRIV" "$TF_FILE"
    update_tfvars "local_public_key" "$LOCAL_PUB" "$TF_FILE"
}

update_tfvars() {
    local key=$1 val=$2 file=$3

    if [[ -f "$file" ]] && grep -q "^${key}[[:space:]]*=" "$file"; then
        sed -i "s|^${key}[[:space:]]*=.*|${key} = \"${val}\"|" "$file"
    else
        echo "${key} = \"${val}\"" >> "$file"
    fi
}

validate_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local ip_arr=($ip)
        [[ ${ip_arr[0]} -le 255 && ${ip_arr[1]} -le 255 && ${ip_arr[2]} -le 255 && ${ip_arr[3]} -le 255 ]]
        return $?
    fi
    return 1
}

# ==========================================
# Main Menu Actions
# ==========================================

# Option 1
generate_keys() {
    if sudo test -f "$WG_CONF"; then
        error "$WG_CONF already exists. Aborting to prevent overwriting.\n${YELLOW}[!] To update existing keys, use Option 3 (Rotate keys).${NC}"
    fi

    # Generate keys and populate globals
    setup_keys_and_tfvars

    warn "Creating $WG_CONF with placeholder endpoint..."
    sudo mkdir -p "$(dirname "$WG_CONF")"

    sudo bash -c "cat <<WG_CONF > $WG_CONF
[Interface]
PrivateKey = ${LOCAL_PRIV}
Address = 10.200.200.2/24

[Peer]
PublicKey = ${EC2_PUB}
Endpoint = REPLACE_ME:${WG_PORT}
AllowedIPs = 10.0.0.0/16, 10.200.200.0/24
PersistentKeepalive = 25
WG_CONF"

    sudo chmod 600 "$WG_CONF"

    info "Keys and initial configuration generated successfully."
    warn "You can now run 'terraform apply'. Once complete, run this script again (Option 2) to set the IP!"
}

# Option 2
set_endpoint() {
    read -p "Enter the new EC2 Public IPv4 Address: " ip_addr

    validate_ipv4 "$ip_addr" || error "Invalid IPv4 format."
    sudo test -f "$WG_CONF" || error "$WG_CONF not found. Please generate keys first (Option 1)."

    sudo sed -i "s|^Endpoint = .*|Endpoint = ${ip_addr}:${WG_PORT}|" "$WG_CONF"
    restart_wg

    info "Endpoint successfully updated to ${ip_addr}:${WG_PORT} in $WG_CONF"
}

# Option 3
rotate_keys() {
    warn "Rotating WireGuard keys..."

    if ! sudo test -f "$WG_CONF" || [[ ! -f "$TF_FILE" ]]; then
        error "Configuration files not found. Cannot rotate keys. Run Option 1 first."
    fi

    # Generate new keys and populate globals
    setup_keys_and_tfvars

    # Update wg0.conf in place
    sudo sed -i "s|^PrivateKey = .*|PrivateKey = ${LOCAL_PRIV}|" "$WG_CONF"
    sudo sed -i "s|^PublicKey = .*|PublicKey = ${EC2_PUB}|" "$WG_CONF"
    
    restart_wg

    info "Keys successfully rotated in $WG_CONF and $TF_FILE."
    warn "Don't forget to run Terraform to push the new keys to your EC2 instance!"
}

# ==========================================
# Pre-flight Checks & Execution
# ==========================================

command -v wg &> /dev/null || error "'wg' command not found. Please install wireguard-tools."
sudo -v

echo ""
echo "========================================="
echo "      WireGuard Setup Menu"
echo "========================================="
echo "1. Generate keys & initial config [Default]"
echo "2. Set endpoint IP (Run after EC2 launch)"
echo "3. Rotate existing keys"
echo "4. Exit"
echo "========================================="
read -p "Select an option [1]: " choice

case ${choice:-1} in
    1) generate_keys ;;
    2) set_endpoint ;;
    3) rotate_keys ;;
    4) info "Exiting..."; exit 0 ;;
    *) error "Invalid option selected. Exiting." ;;
esac
