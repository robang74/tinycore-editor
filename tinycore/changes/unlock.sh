#!/bin/ash
#
# Author: Roberto A. Foglietta
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

type=$(cat /etc/sysconfig/p2type)
tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
dtdev=$(readlink /etc/sysconfig/dtdev)
dtdir=$(readlink /etc/sysconfig/dtdir)
dtdir=${dtdir:-$(devdir $dtdev)}
mount=${type/ext4/mount}
mount=${type/ntfs/ntfs-3g}

if [ "$tcdir" == "" ]; then
	tcdir=${tcdev/dev/mnt}
	mkdir -p $tcdir
fi

if [ "$dtdir" == "" ]; then
	dtdir=$(echo "$dtdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $dtdir
fi

[ "$1" ] || set -- 1 2

if [ "$1" == "1" ]; then
	shift
	if ! grep -qe "^$tcdev .* rw," /proc/mounts; then
		mount -o remount,rw $tcdir 2>/dev/null
	fi
	if grep -qe "^$tcdev .* rw," /proc/mounts; then
		echo "$tcdir (RW)"
	fi
fi

if [ "$1" == "2" ]; then
	if ! grep -qe "^$dtdev .* rw," /proc/mounts; then
		mount -o remount,rw $dtdir 2>/dev/null
		if ! grep -qe "^$dtdev .* rw," /proc/mounts; then
			if grep -q " $dtdir " /proc/mounts; then
				umount $dtdir
			fi 2>/dev/null
			$mount $dtdev $dtdir 2>/dev/null
		fi
	fi
	if grep -qe "^$dtdev .* rw," /proc/mounts; then
		echo "$dtdir (RW)"
	fi
fi

