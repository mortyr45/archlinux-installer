#!/bin/bash

# This script will install Archlinux on your system.

set -euo pipefail

export WHIPTAIL_HEIGHT=20
export WHIPTAIL_WIDTH=78
export WHIPTAIL_LIST_HEIGHT=10
export WHIPTAIL_CANCEL_MESSAGE="Cancelled by the user."

###############################
# Prompts
###############################

function prompt_kernels() {
    set -euo pipefail
    declare chosen_kernels
    chosen_kernels=$(whiptail --notags --checklist "Choose kernel(s) to install:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH $WHIPTAIL_LIST_HEIGHT \
        "linux" "Latest stable linux kernel" ON \
        "linux-lts" "Long-term support linux kernel" OFF \
        "linux-hardened" "Hardened linux kernel" OFF \
        "linux-zen" "Zen linux kernel" OFF 3>&1 1>&2 2>&3)
    echo "$chosen_kernels"
}

function prompt_username() {
    set -euo pipefail
    declare username
    username=$(whiptail --inputbox "Please provide a username for the new user:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$username"
}

function prompt_password() {
    set -euo pipefail
    declare user_password
    user_password=$(whiptail --passwordbox "Please provide a password for the new user:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$user_password"
}

function prompt_hostname() {
    set -euo pipefail
    declare hostname
    hostname=$(whiptail --inputbox "Please provide a hostname for the new system:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH 3>&1 1>&2 2>&3)
    echo "$hostname"
}

function prompt_additional_features() {
    set -euo pipefail
    declare additional_features
    additional_features=$(whiptail --notags --checklist "Choose additional features to install:" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH $WHIPTAIL_LIST_HEIGHT \
        "snapper" "Snapper for system backup on updates" OFF \
        "recovery" "Recovery image in EFI" OFF \
        "iwd" "iwd for wireless network management from the terminal" OFF \
        "linger" "Enable user lingering" OFF \
        "bluetooth" "Bluetooth support" OFF 3>&1 1>&2 2>&3)
    echo "$additional_features" | xargs
}

###############################
# Installation
###############################

function base_install() {
    set -euo pipefail
    pacstrap /mnt $1
    genfstab -U /mnt >/mnt/etc/fstab
}

function user_setup() {
    set -euo pipefail
    echo "Defaults editor=/usr/bin/rnano" >>/mnt/etc/sudoers.d/50_defaults_editor_nano
    echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10_wheel_group

    arch-chroot /mnt useradd --add-subids-for-system --create-home --groups wheel --user-group "$1"
    echo "$1:$2" | arch-chroot /mnt chpasswd
    arch-chroot /mnt passwd --lock root
}

function locale_setup() {
    set -euo pipefail
    arch-chroot /mnt sed -ri -e "s/^#en_US.UTF-8\ UTF-8/en_US.UTF-8\ UTF-8/g" /etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "KEYMAP=us-acentos" >/mnt/etc/vconsole.conf
    echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
    echo "LANGUAGE=en_US.UTF-8" >/mnt/etc/locale.conf
    echo "LC_ALL=en_US.UTF-8" >/mnt/etc/locale.conf
    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
}

function set_hostname() {
    set -euo pipefail
    echo "$1" >/mnt/etc/hostname
}

function configure_network() {
    set -euo pipefail
    mkdir -p /mnt/etc/systemd/resolved.conf.d
    echo "[Resolve]
DNSSEC=allow-downgrade
DNSOverTLS=yes
DNS=1.1.1.1#one.one.one.one
" >/mnt/etc/systemd/resolved.conf.d/50_default.conf

    ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

    echo "[Match]
Name=!veth*

[Network]
DHCP=yes
" >/mnt/etc/systemd/network/90_dhcp.network

    arch-chroot /mnt ufw default deny incoming
    arch-chroot /mnt ufw default allow outgoing
    arch-chroot /mnt ufw default allow routed
}

function configure_systemd_bootloader() {
    set -euo pipefail
    arch-chroot /mnt bootctl install
    echo "default @saved
timeout 3
console-mode keep
editor true
auto-entries true
auto-firmware true
beep false
" > /mnt/boot/efi/loader/loader.conf
}

function configure_mkinitcpio() {
    set -euo pipefail
    rm /mnt/boot/initramfs-*
    declare presets
    presets=$(ls /mnt/etc/mkinitcpio.d/*.preset)
    for preset_file in $presets; do
        preset_file=$(basename "$preset_file")
        kernel_name=$(echo "$preset_file" | cut -d'.' -f1)
        mv "/mnt/etc/mkinitcpio.d/$preset_file" "/mnt/etc/mkinitcpio.d/$preset_file.original"

        echo "FILES=()
HOOKS=(systemd modconf keyboard sd-vconsole block filesystems sd-encrypt)
COMPRESSION=\"zstd\"
" > "/mnt/etc/mkinitcpio.d/$kernel_name.conf"

        echo "PRESETS=('default')
default_config=\"/etc/mkinitcpio.d/$kernel_name.conf\"
default_kver=\"/boot/vmlinuz-$kernel_name\"
default_microcode=\"/boot/*-ucode.img\"
default_uki=\"/boot/efi/EFI/Linux/$kernel_name.efi\"
" > "/mnt/etc/mkinitcpio.d/$preset_file"
    done

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
        echo "rd.luks.name=$luks_uuid=luks_root root=/dev/mapper/luks_root rootflags=subvol=@ rw quiet" > /mnt/etc/kernel/cmdline
    else
        echo "root=UUID=$root_uuid rootflags=subvol=@ rw quiet" > /mnt/etc/kernel/cmdline
    fi
    arch-chroot /mnt mkinitcpio -P
}

function enable_services() {
    set -euo pipefail
    arch-chroot /mnt systemctl enable systemd-{boot-update,timesyncd,oomd,resolved,networkd}.service
}

###############################
# Additional setups
###############################

function setup_snapper() {
    set -euo pipefail
    arch-chroot /mnt pacman -S --noconfirm snapper snap-pac
    arch-chroot /mnt snapper --no-dbus -c root create-config /
}

function setup_recovery() {
    set -euo pipefail
    mkdir /mnt/boot/efi/recovery
    dd if=/dev/sr0 of=/mnt/boot/efi/recovery/cd.iso
    cp /run/archiso/bootmnt/arch/boot/x86_64/* /mnt/boot/efi/recovery/
    echo "title Arch Linux CD image
efi /recovery/vmlinuz-linux
options initrd=/recovery/initramfs-linux.img img_dev=UUID=$1 img_loop=/recovery/cd.iso copytoram
" > "/mnt/boot/efi/loader/entries/recovery.conf"
}

function setup_iwd() {
    set -euo pipefail
    arch-chroot /mnt pacman --noconfirm -S iwd
    arch-chroot /mnt systemctl enable iwd.service
}

function setup_linger() {
    set -euo pipefail
    mkdir -p /mnt/var/lib/systemd/linger
    touch "/mnt/var/lib/systemd/linger/$1"
}

function setup_bluetooth() {
    set -euo pipefail
    arch-chroot /mnt pacman --noconfirm -S bluez bluez-utils
    arch-chroot /mnt systemctl enable bluetooth.service
}

###############################
# Script
###############################

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
additional_features=$(prompt_additional_features)

declare packages
packages="base btrfs-progs dkms efibootmgr iptables-nft linux-firmware mkinitcpio nano pacman-contrib sudo systemd-resolvconf ufw"
for kernel in $(echo "$kernel_choices" | xargs); do
    packages+=" $kernel $kernel-headers"
done

whiptail --yesno "Begin installation?\n
Chosen kernels: $kernel_choices\n
Username: $username\n
Hostname: $hostname\n
Additional features: $additional_features" \
    --defaultno $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH

base_install "$packages"
user_setup "$username" "$password"
locale_setup
set_hostname "$hostname"
configure_network
configure_systemd_bootloader
configure_mkinitcpio
enable_services

[[ "$additional_features" == *"snapper"* ]] && setup_snapper
[[ "$additional_features" == *"recovery"* ]] && setup_recovery "$efi_uuid"
[[ "$additional_features" == *"iwd"* ]] && setup_iwd
[[ "$additional_features" == *"linger"* ]] && setup_linger "$username"
[[ "$additional_features" == *"bluetooth"* ]] && setup_bluetooth
