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

readonly=0
mntdir=$(tcldevdir.sh | cut -d: -f2)
if mount | grep -qe "on $mntdir .* (ro,"; then
	mount -o remount,rw $mntdir
	readonly=1
fi
optional="tce/optional"
cd $mntdir

if [ "$1" == "back" -o "$1" == "reverse" ]; then
	if [ -d tce ]; then
		mkdir -p tcz
		mv -f $optional/*.tcz tcz
		if [ "$1" == "reverse" ]; then
			rm -rf tce
		fi
	fi
	sync
	if [ "$readonly" != "0" ]; then
		mount -o remount,ro $mntdir
	fi
	exit 0
fi

mkdir -p $optional
ls -1 tcz/*.tcz 2>/dev/null && \
	mv -f tcz/*.tcz $optional
cd $optional
ls -1 *.tcz >../onboot.lst 2>/dev/null
sync
if [ "$readonly" != "0" ]; then
	mount -o remount,ro $mntdir
fi

