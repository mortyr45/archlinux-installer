#!/bin/bash

set -euo pipefail

###############################
# Systemd Boot
###############################
# vars: kernel_choices

# Setting up initcpios
echo "HOOKS=(systemd microcode modconf kms block keyboard sd-vconsole sd-encrypt filesystems fsck)
COMPRESSION=\"zstd\"" > /mnt/etc/mkinitcpio.conf.d/custom.conf
rm /mnt/boot/*.img
for kernel in $(echo "$kernel_choices" | xargs); do
    echo "ALL_kver=\"/boot/vmlinuz-$kernel\"
PRESETS=('default')
default_uki=\"/boot/efi/EFI/Linux/$kernel.efi\"" > /mnt/etc/mkinitcpio.d/$kernel.preset
done

# Setting up bootloader
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

arch-chroot /mnt mkinitcpio -P
