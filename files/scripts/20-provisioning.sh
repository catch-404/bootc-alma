#!/bin/bash

set -xeuo pipefail

chmod +x /usr/libexec/first-boot-provision.sh

systemctl enable first-boot-provision.service