#!/bin/bash

set -euo pipefail

declare workdir
workdir="/tmp/fulcrum-arch"

test ! -d $workdir && mkdir $workdir
test ! -f $workdir/disk.img && qemu-img create -f raw $workdir/disk.img 16G
test ! -f $workdir/OVMF_VARS.fd && cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd $workdir/OVMF_VARS.fd

qemu-system-x86_64 \
-accel kvm \
-smp 4 \
-m 4096M \
-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
-drive if=pflash,format=raw,file=$workdir/OVMF_VARS.fd \
-drive file=$workdir/disk.img,index=0,media=disk,format=raw \
-drive file=~/Downloads/archlinux-x86_64.iso,index=1,media=cdrom \
-virtfs local,path=src,mount_tag=src,security_model=mapped-xattr,readonly=on

# mount the share with: mount --mkdir -t 9p src /src
