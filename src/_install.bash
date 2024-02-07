#!/bin/bash

set -euo pipefail

###############################
# Install
###############################
# vars: hostname, packages, username, password, root_uuid

#binutils needed
pacstrap -G -K /mnt $packages
genfstab -U /mnt > /mnt/etc/fstab
echo "$hostname" > /mnt/etc/hostname

echo "Defaults editor=/usr/bin/rnano" >> /mnt/etc/sudoers.d/50_defaults_editor_nano
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/10_wheel_group

arch-chroot /mnt useradd --add-subids-for-system --create-home --groups wheel --user-group "$username"
echo "$username:$password" | arch-chroot /mnt chpasswd
arch-chroot /mnt passwd --lock root

declare luks_root_exists
luks_root_exists=false
grep "/dev/mapper/luks_root" /etc/mtab && luks_root_exists=true
if [ $luks_root_exists == true ]; then
    declare luks_uuid
    readarray -t device_array < <(lsblk --fs --json | jq '.blockdevices' | jq -rc '.[]')
    for device in "${device_array[@]}"; do
        readarray -t partition_array < <(echo "$device" | jq '.children' | jq -rc '.[]')
        for partition in "${partition_array[@]}"; do
            readarray -t mapper_array < <(echo "$partition" | jq '.children' | jq -rc '.[]')
            for mapper in "${mapper_array[@]}"; do
                if [ $(echo "$mapper" | jq -r '.name') == "luks_root" ]; then
                    luks_uuid=$(echo "$partition" | jq -r '.uuid')
                    break 3
                fi
            done
        done
    done
    echo "rd.luks.uuid=$luks_uuid root=UUID=$root_uuid rootflags=subvol=@ rw" > /mnt/etc/kernel/cmdline
else
    echo "root=UUID=$root_uuid rootflags=subvol=@ rw" > /mnt/etc/kernel/cmdline
fi
