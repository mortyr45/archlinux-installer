#!/bin/bash

# This script will install Archlinux on your system.

set -euo pipefail

export WHIPTAIL_HEIGHT=20
export WHIPTAIL_WIDTH=78
export WHIPTAIL_LIST_HEIGHT=10
export WHIPTAIL_CANCEL_MESSAGE="Cancelled by the user."
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $SCRIPT_DIR/_prompts.bash

timedatectl
pacman -Sy --noconfirm jq

declare efi_partition
declare efi_uuid
declare root_partition
declare root_uuid

efi_partition=$(grep "/mnt/boot/efi vfat" /etc/mtab | cut -d' ' -f1)
efi_uuid=$(blkid -s UUID -o value "$efi_partition")
root_partition=$(grep "/mnt btrfs" /etc/mtab | cut -d' ' -f1)
root_uuid=$(blkid -s UUID -o value "$root_partition")

declare kernel_choices
kernel_choices=$(prompt_kernels)
declare username
username=$(prompt_username)
declare password
password=$(prompt_password)
declare hostname
hostname=$(prompt_hostname)
declare additional_features

declare packages
packages="archlinux-keyring binutils dracut efibootmgr iproute2 linux-firmware pacman sudo systemd systemd-resolvconf"
for kernel in $(echo "$kernel_choices" | xargs); do
    packages+=" $kernel $kernel-headers"
done
#binutils needed
pacstrap -G -K /mnt $packages
genfstab -U /mnt >/mnt/etc/fstab
echo "$hostname" >/mnt/etc/hostname

echo "Defaults editor=/usr/bin/rnano" >>/mnt/etc/sudoers.d/50_defaults_editor_nano
echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10_wheel_group

arch-chroot /mnt useradd --add-subids-for-system --create-home --groups wheel --user-group "$username"
echo "$username:$password" | arch-chroot /mnt chpasswd
arch-chroot /mnt passwd --lock root

arch-chroot /mnt systemctl enable systemd-{timesyncd,oomd,resolved,networkd}.service
arch-chroot /mnt systemctl enable serial-getty@ttyS0.service

mkdir -p /mnt/etc/pacman.d/hooks
echo "[Trigger]
Operation = Upgrade
Operation = Install
Type = Package
Target = linux*

[Action]
Depends = dracut
Description = Regenerating unified kernel images...
When = PostTransaction
Exec = /usr/bin/dracut --regenerate-all --uefi --force" > /mnt/etc/pacman.d/hooks/dracut_generate_ukis.hook

echo "[Match]
Name=*

[Network]
DHCP=yes
" > /mnt/etc/systemd/network/50_dhcp.network

arch-chroot /mnt bootctl install
    echo "default @saved
timeout 3
console-mode keep
editor true
auto-entries true
auto-firmware true
beep false
" > /mnt/boot/efi/loader/loader.conf
mkdir -p /mnt/etc/pacman.d/hooks
echo "[Trigger]
Operation = Upgrade
Type = Package
Target = systemd

[Action]
Description = Updating systemd bootloader...
When = PostTransaction
Exec = bootctl --no-variables --graceful update" > /mnt/etc/pacman.d/hooks/update_systemd_bootloader.hook

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
    echo "kernel_cmdline=\"rd.luks.uuid=$luks_uuid root=UUID=$root_uuid rootflags=subvol=@ rw quiet\"" > /mnt/etc/dracut.conf.d/cmdline.conf
else
    echo "kernel_cmdline=\"root=UUID=$root_uuid rootflags=subvol=@ rw quiet\"" > /mnt/etc/dracut.conf.d/cmdline.conf
fi

echo "omit_dracutmodules=\" brltty\"" > /mnt/etc/dracut.conf.d/omit_modules.conf
echo "compress=\"zstd\"" > /mnt/etc/dracut.conf.d/compress.conf
arch-chroot /mnt dracut --regenerate-all --uefi --force
