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

devel=$(cat /etc/sysconfig/devel)
tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
dtdev=$(readlink /etc/sysconfig/dtdev)
dtdir=$(readlink /etc/sysconfig/dtdir)
dtdir=${dtdir:-$(devdir $dtdev)}
dtdir=${dtdir:-${dtdev/dev/mnt}}
devel=${devel:+ext4}
type=${devel:-ntfs}
bkdev=${tcdev%1}

if [ "$type" == "ntfs" ]; then
	fdopt="t\n 2\n 7\n"
	mkopt="-Q"
fi

if ! fdisk -l $bkdev | grep -qe "^$dtdev "; then
#
# Updating the USB key with dd, creates some situations that should be addressed
#
	umount $dtdev 2>/dev/null

	echo "Creating the data partition..."

	echo -e "n\n p\n 2\n \n \n N\n $fdopt w"  | fdisk $bkdev >/dev/null 2>&1
	sleep 1
	partready $dtdev
	if ! fdisk -l $bkdev | grep -qe "^$dtdev "; then
		echo
		echo "ERROR: cannot create data partition in $bkdev"
		echo
		exit 1
	fi

	if [ -z "$dtdir" ]; then
		dtdir=${dtdev/dev/mnt}
		mkdir -p $dtdir
	fi
	mount -t $type $dtdev $dtdir 2>/dev/null
	if grep -qe "^$dtdev $dtdir " /proc/mounts; then
		echo
		echo "data partition rescued, mounted in $dtdir"
		echo
		exit 0
	fi

	echo "Formatting the data partition..."
	if ! mkfs.$type -L DATA -F $mkopt $dtdev >/dev/null; then
		echo
		echo "ERROR: cannot format data partition on $dtdev"
		echo
		exit 1
	fi
fi

if [ "$dtdev" != "" ]; then
	if grep -qe "^$dtdev " /proc/mounts; then
		echo
		echo "data partition is just mounted in $dtdir"
		echo
		exit 0
	fi
	if ! mount -t ext4 $dtdev $dtdir; then
		mount -t ntfs $dtdev $dtdir
	fi 2>/dev/null
	if ! grep -qe "^$dtdev $dtdir " /proc/mounts; then
		echo
		echo "ERROR: cannot mount data partition in $dtdir"
		echo
		exit 1
	fi 
fi
echo
echo "data partition has been mounted in $dtdir"
echo

