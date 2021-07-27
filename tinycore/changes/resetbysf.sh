#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function rrdiskptbl() {
	echo "w" | fdisk $bkdev >/dev/null
	sleep 1
}

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

label="TINYCORE"
tcdev=$(blkid --label $label | head -n1)
if [ "$tcdev" == "" ]; then
	echo
	echo "ERROR: partion label $label not found, abort"
	echo
	exit 1
fi 
ntdev=$(echo $tcdev | sed -e "s,1$,2,")
bkdev=$(echo $tcdev | sed -e "s,1$,,")

if [ "$1" == "" ]; then
	image="/mnt/sf_Shared/tcl-64Mb-usb.disk.gz"
elif [ -f "$1" ]; then
	image="$1"
elif [ -d "$1" ]; then
	image="$1/tcl-64Mb-usb.disk.gz"
else
	echo
	echo "ERROR: parameter is not a file not a directory"
	echo
	exit 1
fi

errot=0
if grep -qe "^$ntdev" /proc/mounts; then
	if ! umount $ntdev; then
		echo "ERROR: device $ntdev is busy"
		echo
		exit 1
	fi
fi
if grep -qe "^$tcdev" /proc/mounts; then
	if ! mount -o remount,ro $tcdev; then
		echo "ERROR: device $tcdev is busy"
		echo
		exit 1
	fi
fi
sync
echo "Image is copying on $bkdev..."
zcat "$image" >$bkdev
sync; sleep 1
echo "Refreshing partition on $bkdev..."
rrdiskptbl $bkdev
if ! fsck -yf $tcdev; then
	if ! fsck -yf $tcdev; then
		error=1
	fi
fi >/dev/null 2>&1
ntfs-usbdisk-partition-create.sh
echo "Checking label '$label' on $bkdev..."
if ! blkid --label $label $bkdev >/dev/null; then
	echo "WARNING: label '$label' not found, it might not boot"
	echo
	echo "         dosfslabel $bkdev $label"
	echo
fi
if [ "$error" = "1" ]; then
	echo "ERROR: root partition ${bkdev}1 is broken"
	echo
	echo "Reboot is require but it could go wrong"
	echo "Fix the problem or repeat this preocedure"
	echo
else
	echo "Please reboot the system immediately"
fi
echo

