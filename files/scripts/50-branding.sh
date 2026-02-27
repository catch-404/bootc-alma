#!/usr/bin/env bash
# Slimemd down version of https://github.com/AlmaLinux/atomic-desktop/raw/refs/heads/main/files/scripts/50-branding.sh

set -xeuo pipefail

rm -rf /usr/share/plasma/look-and-feel/org.fedoraproject.fedora.desktop

sed -i \
    's,org.fedoraproject.fedora.desktop,org.kde.breezetwilight.desktop,g' \
    /usr/share/kde-settings/kde-profile/default/xdg/kdeglobals

sed -i \
    's,#Current=01-breeze-fedora,Current=breeze,g' \
    /etc/sddm.conf

rm -rf /usr/share/wallpapers/Fedora
rm -rf /usr/share/wallpapers/F4*
rm -rf /usr/share/backgrounds/f4*