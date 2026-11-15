#!/bin/bash
set -e

echo "Running post-install tasks."
# Disable post-install service
systemctl disable post-install.service

# Network fix
rm /etc/resolv.conf
resolvconf -u

# Fix keyboard layout

KEYMAP=$(sed -n 's/^KEYMAP=//p' /etc/vconsole.conf | tr -d '"')
if [[ -n "$KEYMAP" ]]; then
    localectl set-keymap "$KEYMAP"
    localectl set-x11-keymap "$KEYMAP"
fi


# Initialize AdGuard Home configuration
ADGUARD_CONFIG="/var/lib/adguardhome/AdGuardHome.yaml"
ADGUARD_DEFAULT="/usr/share/doudou/adguardhome/AdGuardHome.yaml"

if [[ ! -f "$ADGUARD_CONFIG" ]]; then
    install -Dm600 "$ADGUARD_DEFAULT" "$ADGUARD_CONFIG"
fi

chown -R adguardhome:adguardhome /var/lib/adguardhome
chmod 0750 /var/lib/adguardhome
chmod 0600 "$ADGUARD_CONFIG"

systemctl enable --now adguardhome

# Prevent running the service again
install -Dm644 /dev/null /var/lib/doudou/setup-complete