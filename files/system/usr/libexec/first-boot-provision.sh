#!/bin/bash
set -euo pipefail

setfont sun12x22

cleanup() {
    [[ -f /var/lib/first-boot-provisioned ]] && return

    echo ""
    echo "========================================"
    echo "  Provisioning failed or was interrupted"
    echo "========================================"

    if [[ -n "${username:-}" ]]; then
        echo "Removing user '${username}'..."
        userdel -r "$username" 2>/dev/null || true
        groupdel "$username" 2>/dev/null || true
    fi

    [[ -n "$cred_dir" && -d "$cred_dir" ]] && rm -rf "$cred_dir"

    echo "Provisioning will retry on next boot."
}

trap cleanup EXIT

clear
echo "========================================"
echo "         User Provisioning"
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
    if [[ ${#password} -lt 8 ]]; then
        echo "Password must be at least 8 characters."
        continue
    fi
    read -r -s -p "Confirm password: " password_confirm
    echo
    [[ "$password" == "$password_confirm" ]] && break
    echo "Passwords do not match. Try again."
done

echo "Creating user '$username'..."
password_hash=$(openssl passwd -6 -- "$password")
groupadd --gid 1000 "$username"
useradd -m -u 1000 -g 1000 -c "$display_name" -p "$password_hash" "$username"
echo "Done."

# --- LUKS reencryption ---
echo ""
echo "========================================"
echo "       LUKS Encryption Provisioning"
echo "========================================"
echo ""

luks_device=$(blkid -t TYPE=crypto_LUKS -o device 2>/dev/null | head -1 || true)

if [[ -z "$luks_device" ]]; then
    echo "FATAL: no LUKS device found!"
    echo "This is never expected nor normal. You should reinstall."
    read -r -p "Press Enter to exit"
    exit 1
fi
echo "LUKS device: $luks_device"
echo ""

luks_dump=$(cryptsetup luksDump --dump-json-metadata "$luks_device")
original_digest=$(echo "$luks_dump" | jq '.digests[] | .digest')
keyslot_salts=$(echo "$luks_dump" | jq '.keyslots[] | .kdf.salt')
if [[ $(echo "$keyslot_salts" | wc -l) -gt 1 ]]; then 
    echo "FATAL: there are multiple keys!"
    echo "This is never expected nor normal. You should reinstall."
    read -r -p "Press Enter to exit"
    exit 1
fi
original_keyslot_salt="$keyslot_salts" # At that point there should only be one salt in the list

read -r -s -p "Enter current disk enrollment passphrase: " original_passphrase
echo ""

if ! printf '%s' "$original_passphrase" \
        | cryptsetup open --test-passphrase --batch-mode "$luks_device" 2>/dev/null; then
    echo "Error: incorrect passphrase."
    read -r -p "Press Enter to exit"
    exit 1
fi

echo "Passphrase verified."

recovery_key=$(set +o pipefail; head -c 1024 /dev/urandom | tr -dc 'A-Z0-9' | head -c 40 | fold -w5 | paste -sd'-')

echo "Adding recovery key to keyslot..."
printf '%s' "$recovery_key" \
    | cryptsetup luksAddKey \
        --batch-mode \
        --key-file <(printf '%s' "$original_passphrase") \
        "$luks_device"

echo ""
echo "========================================"
echo "   RECOVERY KEY - store this safely:"
echo "========================================"
echo ""
echo "$recovery_key"
echo ""
qrencode -t UTF8 "$recovery_key"
echo ""
read -r -p "Press Enter to continue..."
clear

echo "Removing original enrollment passphrase..."
printf '%s' "$original_passphrase" \
    | cryptsetup luksRemoveKey --batch-mode "$luks_device"
unset original_passphrase

echo "Regenerating volume master key. This will take a while..."
cryptsetup reencrypt \
    --key-file <(printf '%s' "$recovery_key") \
    --resilience checksum \
    --progress-frequency 5 \
    --verbose \
    "$luks_device"
echo "Reencryption complete."

if systemd-cryptenroll --tpm2-device=list 2>/dev/null | grep -q "/dev/"; then
    echo "TPM2 detected. Enrolling disk unlock via TPM2 + PIN."

    cred_dir=$(mktemp -d)
    chmod 700 "$cred_dir"
    printf '%s' "$recovery_key" > "$cred_dir/cryptenroll.passphrase"
    printf '%s' "$password" > "$cred_dir/cryptenroll.new-tpm2-pin"

    CREDENTIALS_DIRECTORY="$cred_dir" systemd-cryptenroll \
        --tpm2-device=auto \
        --tpm2-pcrs=7 \
        --tpm2-with-pin=yes \
        "$luks_device"

    rm -rf "$cred_dir"

    clear
    echo "TPM2 enrolled!"
    echo "At each boot you will be prompted for the TPM PIN (user password)."
    echo "The recovery key unlocks the disk if the TPM is unavailable."
    read -r -p "Press Enter to continue..."

    echo
    if mokutil --sb-state 2>/dev/null | grep -iq 'secureboot enabled'; then
        echo "SecureBoot enabled!"
        echo "Make sure your UEFI firmware is password-protected"
        read -r -p "Press Enter to acknowledge..."
    else
        echo "WARNING: SecureBoot is disabled (or in setup mode)!"
        echo "You should enable it in UEFI before using this device."
        echo "Additionally, make sure your UEFI firmware is password-protected."
        read -r -p "Press Enter to acknowledge..."
    fi
else
    echo "No TPM2 detected. Adding user password as LUKS keyslot..."

    printf '%s' "$password" | cryptsetup luksAddKey \
        --batch-mode \
        --key-file=<(printf '%s' "$recovery_key") \
        "$luks_device"
fi

unset recovery_key

luks_dump=$(cryptsetup luksDump --dump-json-metadata "$luks_device")
new_digest=$(echo "$luks_dump" | jq '.digests[] | .digest')
if [[ "$original_digest" == "$new_digest" ]]; then
    echo "FATAL: volume key digest did not change after reencrypt!"
    echo "This is never expected nor normal. You should reinstall."
    read -r -p "Press Enter to exit"
    exit 1
fi

keyslot_salts=$(echo "$luks_dump" | jq '.keyslots[] | .kdf.salt')
if [[ $keyslot_salts == *"$original_keyslot_salt"* ]]; then
    echo "FATAL! The original placeholder passphrase is still present!"
    echo "This is never expected nor normal. You should reinstall."
    read -r -p "Press Enter to exit"
    exit 1
fi

echo "Backing up LUKS header..."
luks_uuid=$(cryptsetup luksUUID "$luks_device")
header_backup="/var/lib/luks-header-${luks_uuid}.img"
cryptsetup luksHeaderBackup "$luks_device" \
    --header-backup-file "$header_backup"
chmod 600 "$header_backup"
echo "Header backed up to: $header_backup"

unset password password_confirm

# --- WireGuard keypair ---
echo ""
echo "========================================"
echo "          WireGuard Provisioning"
echo "========================================"
echo ""
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

private_key=$(wg genkey)
public_key=$(printf '%s' "$private_key" | wg pubkey)

echo "========================================"
echo "  WIREGUARD PUBLIC KEY - add to server:"
echo "========================================"
echo ""
echo "$public_key"
echo ""
qrencode -t UTF8 "$public_key"
echo ""
unset public_key

printf '%s\n' "$private_key" > /etc/wireguard/private.key
chmod 600 /etc/wireguard/private.key
chown root:root /etc/wireguard/private.key
unset private_key

touch /var/lib/first-boot-provisioned

echo "Press Enter to reboot..."
read -r
