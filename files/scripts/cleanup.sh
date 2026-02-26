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
rm -r /usr/local
ln -s /var/usrlocal /usr/local
