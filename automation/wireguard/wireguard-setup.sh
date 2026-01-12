#!/bin/bash

echo "SERVER_PUB_IP=$(curl -s curl http://checkip.amazonaws.com)
SERVER_PUB_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
SERVER_WG_NIC=\"wg0\"
SERVER_WG_IPV4=\"10.66.66.1\"
SERVER_WG_IPV6=\"fd42:42:42::1\"
SERVER_PORT=61517
CLIENT_DNS_1=\"1.1.1.1\"
CLIENT_DNS_2=\"1.0.0.1\"
ALLOWED_IPS=\"0.0.0.0/0,::/0\"
APPROVE_INSTALL=\"y\"

# Client Config
CLIENT_NAME=\"homelab01\"
APPROVE_IP=\"y\"" > ".env"

cat .env

sudo yum update
sudo yum upgrade

curl -sO https://raw.githubusercontent.com/codeunbound/homelab/refs/heads/main/automation/wireguard/wireguard-install.sh
chmod +x wireguard-install.sh
sudo ./wireguard-install.sh