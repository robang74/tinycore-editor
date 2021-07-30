#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

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

tcdev=$(readlink -f /etc/sysconfig/tcdev)
tcdir=$(readlink -f /etc/sysconfig/tcdir)
ntdev=$(readlink -f /etc/sysconfig/ntdev)
ntdir=$(devdir $ntdev)
bkdev=${tcdev%1}

if ! fdisk -l $bkdev | grep -e "^$ntdev"; then
#
# Updating the USB key with dd, creates some situations that should be addressed
#
	umount $ntdev 2>/dev/null

	echo "Creating the ntfs partition..."

	echo -e "n\n p\n 2\n \n \n N\n w"  | fdisk $bkdev >/dev/null 2>&1
	sleep 1

	if ! fdisk -l $bkdev | grep -qe "^$ntdev "; then
		echo
		echo "ERROR: cannot create ntfs partition in $bkdev"
		echo
		exit 1
	else
		echo -e "t\n 2\n 7\n w" | fdisk $bkdev >/dev/null 2>&1
		sleep 1
	fi

	ntfslabel $ntdev NTFS 2>/dev/null || true
	if mount -t ntfs $ntdev $ntdir; then
		echo
		echo "ntfs partition rescued, mounted in $ntdir"
		echo
		exit 0
	fi 2>/dev/null

	echo "Formatting the ntfs partition..."
	if ! mkfs -t ntfs -L NTFS -F -Q $ntdev >/dev/null; then
		echo
		echo "ERROR: cannot format ntfs partition on $ntdev"
		echo
		exit 1
	fi
	
fi

if mount | grep -q "$ntdev on"; then
	ntdir=$(mount | grep -e "$ntdev on" | cut -d' ' -f3)
	echo
	echo "ntfs partition is just mounted in $ntdir"
	echo
	exit 0
fi

if ! mount -t ntfs $ntdev $ntdir; then
	echo
	echo "ERROR: cannot mount ntfs partition in $ntdir"
	echo
	exit 1
fi

echo
echo "ntfs partition has been mounted in $ntdir"
echo

