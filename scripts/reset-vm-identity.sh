#!/bin/bash
# Reset VM Identity for cloned Rocky Linux 10
# This script ensures a cloned VM gets a unique machine-id, hostname, and IP address.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or with sudo)"
   exit 1
fi

NEW_HOSTNAME=$1
NEW_IP=$2
GATEWAY="${3:-192.168.250.1}"

if [ -z "$NEW_HOSTNAME" ] || [ -z "$NEW_IP" ]; then
    echo "Usage: $0 <new-hostname> <new-ip> [gateway]"
    echo "Example: $0 k8s-worker-1 192.168.250.21"
    exit 1
fi

echo "[1/4] Resetting machine-id..."
rm -f /etc/machine-id /var/lib/dbus/machine-id
dbus-uuidgen --ensure=/etc/machine-id
systemd-machine-id-setup

echo "[2/4] Setting hostname to $NEW_HOSTNAME..."
hostnamectl set-hostname "$NEW_HOSTNAME"

echo "[3/4] Updating Network IP to $NEW_IP..."
# Find the active connection name
CONN_NAME=$(nmcli -t -f NAME connection show --active | head -n 1)
if [ -n "$CONN_NAME" ]; then
    echo "Modifying connection: $CONN_NAME"
    nmcli connection modify "$CONN_NAME" ipv4.addresses "$NEW_IP/24" ipv4.gateway "$GATEWAY" ipv4.dns "$GATEWAY,8.8.8.8" ipv4.method manual
    echo "[4/4] Restarting network connection..."
    nmcli connection up "$CONN_NAME"
else
    echo "Warning: Could not find active network connection to update IP automatically."
    echo "Please use 'nmtui' or 'nmcli' to configure the IP manually."
fi

echo "Identity reset complete! It is highly recommended to reboot the VM now: sudo reboot"
