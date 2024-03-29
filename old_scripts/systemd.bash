#!/bin/bash

set -euo pipefail

export WHIPTAIL_HEIGHT=20
export WHIPTAIL_WIDTH=78
export WHIPTAIL_LIST_HEIGHT=10
export WHIPTAIL_CANCEL_MESSAGE="Cancelled by the user."
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/_prompts.bash
source $SCRIPT_DIR/_pre_install.bash

# Setting packages
declare packages
packages="archlinux-keyring efibootmgr iproute2 linux-firmware mkinitcpio nano pacman sed sudo systemd systemd-resolvconf"
for kernel in $(echo "$kernel_choices" | xargs); do
    packages+=" $kernel $kernel-headers"
done

source $SCRIPT_DIR/_install.bash

# Enabling services
arch-chroot /mnt systemctl enable systemd-{timesyncd,oomd,resolved,networkd}.service
arch-chroot /mnt systemctl enable serial-getty@ttyS0.service

# Enabling DHCP
echo "[Match]
Name=*

[Network]
DHCP=yes
" > /mnt/etc/systemd/network/50_dhcp.network

source $SCRIPT_DIR/_systemd-boot.bash
