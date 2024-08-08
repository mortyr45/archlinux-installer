#!/bin/bash

set -euo pipefail

declare workdir
workdir="/tmp/fulcrum-arch"

test ! -d $workdir && mkdir $workdir
test ! -f $workdir/disk.img && qemu-img create -f qcow2 $workdir/disk.img 16G
test ! -f $workdir/OVMF_VARS.fd && cp /usr/share/edk2-ovmf/x64/OVMF_VARS.fd $workdir/OVMF_VARS.fd

qemu-system-x86_64 \
-accel kvm \
-smp 4 \
-m 4096M \
-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
-drive if=pflash,format=raw,file=$workdir/OVMF_VARS.fd,snapshot=on \
-drive file=$workdir/disk.img,index=0,media=disk,format=qcow2 \
-drive file=~/Downloads/archlinux-x86_64.iso,index=1,media=cdrom \
-virtfs local,path=src,mount_tag=src,security_model=mapped-xattr,readonly=on \
-display gtk,gl=on \
-nic user,net=192.168.200.0/24,dhcpstart=192.168.200.10,hostfwd=tcp::9090-:9090 \
# -device e1000,netdev=net0 \
# -netdev user,id=net0,hostfwd=tcp::9090-:9090 \
# -nic user,net=192.168.200.0/24 \
#-device virtio-vga-gl \
#-nographic -serial tcp:127.0.0.1:1234,server=on,wait=off -monitor none

# mount the share with: mount --mkdir -t 9p src /src
