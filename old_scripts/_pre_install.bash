#!/bin/bash

set -euo pipefail

###############################
# Pre-Install
###############################
# vars: prompt_kernels, prompt_username, prompt_password, prompt_hostname

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
