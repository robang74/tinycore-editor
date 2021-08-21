#!/bin/ash
#
# Author: Roberto A. Foglietta
#

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

tcdir=$(readlink /etc/sysconfig/tcdir)
cd $tcdir

for i in $(ls -1 tcz/*-meta.tcz 2>/dev/null); do
	if [ "$1" == "back" -o "$1" == "reverse" ]; then
		break;
	else
		echo
		echo "The tce folder is not compliat with meta-package, abort"
		echo
		exit 1
	fi
	break
done

readonly=0
if grep -qe " $tcdir .* ro," /proc/mounts; then
	mount -o remount,rw $tcdir
	if ! grep -qe " $tcdir .* rw," /proc/mounts; then
		echo
		echo "Cannot remount in read-write the $tcdir, abort"
		echo
		exit 1
	fi
	readonly=1
fi
optional="tce/optional"

if [ "$1" == "back" -o "$1" == "reverse" ]; then
	if [ -d tce ]; then
		echo
		mkdir -p tcz
		mv -f $optional/*.tcz* tcz
		if [ "$1" == "reverse" ]; then
			rm -rf tce
			mkdir -p /tmp/tce
			rm -f /etc/sysconfig/tcedir
			ln -sf /tmp/tce /etc/sysconfig/tcedir
		fi
		ls -1 tcz/*.tcz 2>/dev/null
		echo
	fi
	sync
	if [ "$readonly" != "0" ]; then
		mount -o remount,ro $tcdir
	fi
	exit 0
fi

echo
mkdir -p $optional
ls -1 tcz/*.tcz 2>/dev/null && \
	mv -f tcz/*.tcz* $optional
cd $optional
ls -1 *.tcz >../onboot.lst 2>/dev/null
rm -f /etc/sysconfig/tcedir
ln -sf $tcdir/tce /etc/sysconfig/tcedir
sync

if [ "$readonly" != "0" ]; then
	mount -o remount,ro $tcdir
fi
echo

