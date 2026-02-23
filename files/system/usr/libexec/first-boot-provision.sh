#!/bin/bash
set -euo pipefail

clear
echo "========================================"
echo "         First Boot Provisioning"
echo "========================================"
echo ""

# --- User creation ---
while true; do
    read -r -p "Username: " username
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
    echo "Invalid username. Lowercase letters, numbers, hyphens and underscores only."
done

read -r -p "Display name (full name): " display_name

while true; do
    read -r -s -p "Password: " password
    echo
    read -r -s -p "Confirm password: " password_confirm
    echo
    [[ "$password" == "$password_confirm" ]] && break
    echo "Passwords do not match. Try again."
done

echo "Creating user '$username'..."
# create group 1000 first here maybe
useradd -m -c "$display_name" "$username"
echo "$username:$password" | chpasswd
unset password password_confirm
echo "Done."

# --- WireGuard keypair ---
echo ""
echo "Generating WireGuard keypair..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

private_key=$(wg genkey)
public_key=$(printf '%s' "$private_key" | wg pubkey)

printf '%s\n' "$private_key" > /etc/wireguard/private.key
chmod 600 /etc/wireguard/private.key
chown root:root /etc/wireguard/private.key
unset private_key

echo ""
echo "========================================"
echo "  WireGuard Public Key — add to server:"
echo "========================================"
echo ""
echo "$public_key"
echo ""

# show its qr code

# end it with a cryptsetup reencrypt

# Mark provisioning complete (survives upgrades, see note in unit file)
touch /var/lib/first-boot-provisioned

echo "Press Enter to continue booting..."
read -r
