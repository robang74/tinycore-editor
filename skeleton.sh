#!/bin/bash
#
# (C) 2022 Roberto A. Foglietta, MIT
#

function diskfatresize() {
	local loop=$(losetup -f)
	losetup -P $loop $1
	trap "losetup -d $loop" EXIT
	fatresize -i -n 1 $loop | grep size:
	fatresize -vfs ${2}M -n 1 $loop
	fatresize -i -n 1 $loop | grep size:
	losetup -d $loop
	trap - EXIT
}

set -ex
size=${1:-256}
disk=${size}MB.disk
zcat tcl-skeleton.disk.gz >$disk

old_size=$(du -b $disk | cut -f1)
new_size=$[size*1024*1000]

if [ $new_size -lt $old_size ]; then
	diskfatresize $disk $size
	qemu-img resize --shrink -f raw $disk ${size}M
elif [ $new_size -gt $old_size ]; then
	qemu-img resize -f raw $disk ${size}M
	echo -e "d\n n\n \n \n \n \n t\n b\n w\n" |\
		sudo fdisk $disk
	#RAF, TODO: this currently fails
	diskfatresize $disk $size
fi

gzip -9c $disk > tcl-skeleton-$size.disk.gz
chown $SUDO_USER.$SUDO_USER tcl-skeleton-${size}.disk.gz
ln -sf tcl-skeleton-${size}.disk.gz tcl-skeleton.disk.gz
chown $SUDO_USER.$SUDO_USER -h tcl-skeleton.disk.gz
ls -1l tcl-skeleton.disk.gz
#gparted $loop
rm -f $disk

exit 0 ###################################################
#
# syslinux complains about geometry in some distributions
#
##########################################################

#dd if=/dev/zero bs=1M count=$size of=$disk
img_size=$[size*1024*1024]
# bytes per sector
bytes=512
# sectors per track
sectors=63
# heads per track
heads=255
# bytes per cylinder is bytes*sectors*head
bpc=$[bytes*sectors*heads]
# number of cylinders
cylinders=$[$img_size/$bpc]
# rebound the size
img_size=$[$cylinders*$bpc]
qemu-img create -f raw $disk $img_size
#dd if=/dev/zero count=$[img_size/512] of=$disk
echo -e "n\n \n \n \n \n t\n b\n a\n w" |\
	fdisk -H $heads -S $sectors -C $cylinders $disk
loop=$(losetup -f)
losetup -P $loop $disk
mkfs.vfat ${loop}p1
mkdir -p tmp
mount ${loop}p1 tmp
tar xvzf tcl-boot-syslinux.tgz -moC tmp
sed -i "s,vga=771,vga=791," tmp/boot/syslinux/syslinux.cfg
umount tmp
syslinux -H $heads -S $sectors -d /boot/syslinux -i ${loop}p1 || true
zcat tcl-usb-boot-enable.gz >$loop
sync 
losetup -d $loop
gzip -9c $disk >tcl-skeleton-${size}.disk.gz
ln -sf tcl-skeleton-${size}.disk.gz tcl-skeleton.disk.gz
chown $SUDO_USER.$SUDO_USER tcl-skeleton-${size}.disk.gz
chown $SUDO_USER.$SUDO_USER -h tcl-skeleton.disk.gz
ls -1l tcl-skeleton.disk.gz
rm -f $disk
