#!/bin/bash

set -xeuo pipefail

chmod 700 /usr/libexec/first-boot-provision.sh
chown root:root /usr/libexec/first-boot-provision.sh

systemctl enable first-boot-provision.service