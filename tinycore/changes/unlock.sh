#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

tcdev=$(blkid | grep -e "=.TINYCORE. " | cut -d: -f1)
tcdir=$(mount | grep -e "$tcdev on" | cut -d' ' -f3)
ntdev=$(echo $tcdev | sed -e "s,1$,2,")
ntdir=$(mount | grep -e "$ntdev on" | cut -d' ' -f3)

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
