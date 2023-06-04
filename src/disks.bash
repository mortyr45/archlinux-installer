#!/bin/bash

# This script formats your root and /boot partition, and mounts them into the
# /mnt directory.

set -euo pipefail

export WHIPTAIL_HEIGHT=20
export WHIPTAIL_WIDTH=78
export WHIPTAIL_LIST_HEIGHT=10
export WHIPTAIL_CANCEL_MESSAGE="Cancelled by the user."

function prompt_partition_choice() {
    set -euo pipefail
    declare devices
    devices=$(blkid --output device)
    declare menuoptions=""
    for device in $devices; do
        menuoptions+=" $device $device OFF"
    done
    declare result
    result=$(whiptail --notags --radiolist "$1" \
        $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH $WHIPTAIL_LIST_HEIGHT \
        $menuoptions \
        3>&1 1>&2 2>&3)
    echo "$result"
}

declare efi_partition
efi_partition=$(prompt_partition_choice "EFI partition:")
declare root_partition
root_partition=$(prompt_partition_choice "Root partition:")

declare luks_encryption
luks_encryption=false
if whiptail --yesno --defaultno "Would you like to encrypt the root partition?" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH; then luks_encryption=true; fi

whiptail --yesno --defaultno "Format the following partitions?:\n
$efi_partition (vfat)\n
$root_partition (btrfs$(test $luks_encryption == true && echo ', encrypted'))" $WHIPTAIL_HEIGHT $WHIPTAIL_WIDTH

mkfs.fat -I -F 32 "$efi_partition"

if $luks_encryption; then
    cryptsetup luksFormat "$root_partition"
    cryptsetup open "$root_partition" luks_root
    root_partition="/dev/mapper/luks_root"
fi

mkfs.btrfs -f "$root_partition"
mount "$root_partition" /mnt
btrfs quota disable /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
umount /mnt
mount "$root_partition" -o subvol=@ /mnt
mount --mkdir "$root_partition" -o subvol=@home /mnt/home
mount --mkdir "$root_partition" -o subvol=@var /mnt/var

mount --mkdir "$efi_partition" /mnt/boot/efi
