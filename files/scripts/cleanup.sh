#!/usr/bin/env bash

set -xeuo pipefail

# Image cleanup
# Specifically called by build.sh

# Image-layer cleanup
shopt -s extglob

dnf clean all

rm -rf /.gitkeep /var /boot
mkdir -p /boot /var

# Make /usr/local writeable
if [[ -d /usr/local ]]; then
    mv /usr/local /var/usrlocal
else
    rm /usr/local
fi
ln -s /var/usrlocal /usr/local
