#!/bin/bash
set -e
size=${1:-256}
disk=${size}MB.disk
dd if=/dev/zero bs=1M count=$size of=$disk
echo -e "n\n \n \n \n \n t\n b\n a\n w" | fdisk $disk
loop=$(losetup -f)
losetup -P $loop $disk
mkfs.vfat ${loop}p1
mkdir -p tmp
mount ${loop}p1 tmp
tar xvzf tcl-boot-syslinux.tgz -moC tmp
sed -i "s,vga=771,vga=791," tmp/boot/syslinux/syslinux.cfg
umount tmp
zcat tcl-usb-boot-enable.gz >$loop
syslinux -d /boot/syslinux -sufiz ${loop}p1 || true
losetup -d $loop
gzip -9c $disk >tcl-skeleton-${size}.disk.gz
ln -sf tcl-skeleton-${size}.disk.gz tcl-skeleton.disk.gz
chown $SUDO_USER.$SUDO_USER tcl-skeleton-${size}.disk.gz
chown $SUDO_USER.$SUDO_USER -h tcl-skeleton.disk.gz
ls -1l tcl-skeleton.disk.gz
rm -f $disk
