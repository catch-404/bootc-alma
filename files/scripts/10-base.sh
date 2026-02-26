#!/usr/bin/env bash

set -xeuo pipefail

# EPEL
dnf install -y 'dnf-command(config-manager)' epel-release
dnf config-manager --set-enabled crb
dnf upgrade -y $(dnf repoquery --installed --qf '%{name}' --whatprovides epel-release)

# KDE minimal
dnf install -y --setopt=group_package_types=mandatory @"KDE"

# Other needed packages
dnf install -y \
    glibc-langpack-fr \
    plymouth \
    plymouth-system-theme \
    kde-settings \
    kscreen \
    NetworkManager \
    NetworkManager-wifi \
    plasma-nm \
    krdc \
    fapolicyd \
    wireguard-tools \
    qrencode

# Unnecessary things
dnf remove -y \
    nfs-utils \
    quota \
    rpcbind \
    cloud-utils-growpart \
    WALinuxAgent-udev \
    kdump-utils \
    kexec-tools \
    makedumpfile \
    PackageKit \
    qt6-qtwebengine \
    ghostscript \
    libgs

# TZ
ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime