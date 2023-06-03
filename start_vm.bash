#!/bin/bash

set -euo pipefail

test ! -d tmp && mkdir tmp && chattr +C tmp
test ! -f tmp/disk.img && qemu-img create -f raw tmp/disk.img 8G
test ! -f tmp/OVMF_VARS.fd && cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd tmp/OVMF_VARS.fd

qemu-system-x86_64 \
-accel kvm \
-smp 2 \
-m 2048M \
-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
-drive if=pflash,format=raw,file=tmp/OVMF_VARS.fd,snapshot=on \
-drive file=tmp/disk.img,index=0,media=disk,snapshot=on,format=raw \
-drive file=~/Downloads/archlinux-x86_64.iso,index=1,media=cdrom \
-virtfs local,path=src,mount_tag=src,security_model=mapped-xattr,readonly=on \
-display gtk,gl=off,grab-on-hover=off,show-tabs=on,show-cursor=off

# mount the share with: mount --mkdir -t 9p src /src
