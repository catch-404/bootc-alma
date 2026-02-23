#!/usr/bin/env bash

set -xeuo pipefail

# Packages
dnf install -y \
    fapolicyd \
    krdc \
    wireguard-tools \
    qrencode

dnf remove -y \
    cockpit \
    cockpit-bridge \
    cockpit-ws \
    cockpit-ws-selinux \
    plasma-discover \
    plasma-discover-libs \
    flatpak \
    flatpak-libs \
    flatpak-selinux \
    flatpak-session-helper \
    konsole \
    konsole-part \
    krfb

# systemd
systemctl disable system-flatpak-setup.timer
systemctl --global disable user-flatpak-setup.timer

# TZ
ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime

# Autologin
mkdir -p /etc/systemd/system/graphical.target.wants/
ln -s /etc/systemd/system/sddm-autologin-setup.service /etc/systemd/system/graphical.target.wants/sddm-autologin-setup.service