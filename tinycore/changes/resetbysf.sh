#!/bin/ash
#
# Author: Roberto A. Foglietta
#

function partready() {
	part=$(basename $1)
	if ! grep -qe "$part$" /proc/partitions; then
		sleep 1
	fi
	if [ ! -b $1 ]; then
		sleep 1
	fi
	grep -qe "$part$" /proc/partitions
}

function rrdiskptbl() {
	echo "w" | fdisk $bkdev >/dev/null
	partready ${bkdev}1
}

function devdir() {
	sed -ne "s,^$1 \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

tcdev=$(readlink /etc/sysconfig/tcdev)
dtdev=$(readlink /etc/sysconfig/dtdev)
dtdir=$(readlink /etc/sysconfig/dtdir)
dtdir=${dtdir:-$(devdir $dtdev)}
bkdev=${tcdev%1}

if [ "$tcdev" == "" ]; then
	echo
	echo "ERROR: tinycore partion not found, abort"
	echo
	exit 1
fi

imgname=tcl-usb.disk.gz
dirlist="
/mnt/sf_Shared
/home/tc
/root
/
$dtdir
"
if [ "$1" == "" ]; then
	for i in $dirlist; do
		if [ -e $i/$imgname ]; then
			set -- $i/$imgname
			break;
		fi
	done
fi
if [ -d "$1" -a -f $1/$imgname ]; then
	image="$1/$imgname"
elif [ -f "$1" ]; then
	image="$1"
else
	echo
	echo "ERROR: parameter is not a file not a directory"
	echo
	exit 1
fi
echo "Image: $(realpath $image)"

errot=0
if grep -qe "^$dtdev " /proc/mounts; then
	if ! umount $dtdev; then
		echo "ERROR: device $dtdev is busy"
		echo
		exit 1
	fi
fi
if grep -qe "^$tcdev " /proc/mounts; then
	mount -o remount,ro $tcdev
	if ! grep -qe "^$tcdev .* ro," /proc/mounts; then
		echo "ERROR: device $tcdev is busy"
		echo
		exit 1
	fi
fi
sync
echo "Image is copying on $bkdev..."
if ! zcat $image >$bkdev; then
	echo "ERROR: device ${tcdev} not initialised"
	echo
	echo "Do not reboot, the system will fail"
	echo "Fix the problem or repeat this procedure"
	echo	
fi
sync; sleep 1
echo "Refreshing partition on $bkdev..."
rrdiskptbl $bkdev
#if ! fsck -yf $tcdev; then
#	if ! fsck -yf $tcdev; then
#		error=1
#	fi
#fi >/dev/null 2>&1
data-usbdisk-partition-create.sh

if [ "$error" = "1" ]; then
	echo "ERROR: root partition ${tcdev} is broken"
	echo
	echo "Reboot is require but it could fail"
	echo "Fix the problem or repeat this procedure"
	echo
else
	echo "Please reboot the system immediately"
fi
echo

