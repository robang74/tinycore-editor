#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function devdir() {
	sed -ne "s,^$1 \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
ntdev=$(readlink /etc/sysconfig/ntdev)
ntdir=$(devdir $ntdev)

if [ "$tcdir" == "" ]; then
	tcdir=$(echo "$tcdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $tcdir
fi

if [ "$ntdir" == "" ]; then
	ntdir=$(echo "$ntdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $ntdir
fi

if ! mount | grep -qe "^$tcdev .* (rw,"; then
	if mount -o remount,rw $tcdir; then
		echo "$tcdir (RW)"
	fi 2>/dev/null
else
	echo "$tcdir (RW)"
fi

mount -o remount,rw $ntdir 2>/dev/null
if ! mount | grep -qe "^$ntdev .* (rw,"; then
	if mount | grep -q $ntdir; then
		sync
		umount $ntdir
	fi 2>/dev/null
	if ntfs-3g $ntdev $ntdir; then
		echo "$ntdir (RW)"
	fi 2>/dev/null
else
	echo "$ntdir (RW)"
fi
