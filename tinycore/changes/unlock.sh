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
ntdir=$(readlink /etc/sysconfig/ntdir)
ntdir=${ntdir:-$(devdir $ntdev)}

if [ "$tcdir" == "" ]; then
	tcdir=${tcdev/dev/mnt}
	mkdir -p $tcdir
fi

if [ "$ntdir" == "" ]; then
	ntdir=$(echo "$ntdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $ntdir
fi

mount -o remount,rw $tcdir 2>/dev/null
if grep -qe "^$tcdev .* rw," /proc/mounts; then
	echo "$tcdir (RW)"
fi

mount -o remount,rw $ntdir 2>/dev/null
if ! grep -qe "^$ntdev .* rw," /proc/mounts; then
	if grep -q " $ntdir " /proc/mounts; then
		umount $ntdir
	fi 2>/dev/null
	ntfs-3g $ntdev $ntdir 2>/dev/null
fi
if grep -qe "^$ntdev .* rw," /proc/mounts; then
	echo "$ntdir (RW)"
fi

