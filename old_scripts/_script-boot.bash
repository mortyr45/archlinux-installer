#!/bin/bash

set -euo pipefail

###############################
# Systemd Boot
###############################
# vars: kernel_choices

# Setting up initcpios & boot scripts
echo "HOOKS=(systemd modconf kms block keyboard sd-vconsole sd-encrypt filesystems fsck)
COMPRESSION=\"zstd\"" > /mnt/etc/mkinitcpio.conf.d/custom.conf
rm /mnt/boot/*.img
for kernel in $(echo "$kernel_choices" | xargs); do
    echo "ALL_kver=\"/boot/vmlinuz-$kernel\"
ALL_microcode=(/boot/*-ucode.img)
PRESETS=('default')
default_uki=\"/boot/efi/$kernel.efi\"" > /mnt/etc/mkinitcpio.d/$kernel.preset
done
echo "${kernel_choices[0]}.efi" > /mnt/boot/efi/startup.nsh

arch-chroot /mnt mkinitcpio -P
