#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

myname=$(basename $0)

function usage() {
	echo
	echo "USAGE: $myname [open|close|clean|update]"
	echo
}

function errexit() {
	echo
	echo "ERROR: $1"
	echo
	exit 1
}

ok=0
if [ "$USER" != "root" ]; then
	sudo $0 "$@"
	exit $?
fi

cd $(dirname $0)
WRKDIR="$PWD"

echo
echo "Working folder is $WRKDIR"

if [ "$1" == "open" -o "$1" == "update" ]; then
	ok=1
	if [ -d rootfs ]; then
		errexit "directory rootfs found, abort"	
	fi
	mkdir rootfs
	cd rootfs
	echo -n "open : "
	zcat ../rootfs.gz | sudo cpio -i
	cat ../changes/rcS > etc/init.d/rcS
	cd ..
fi

if [ "$1" == "close" -o "$1" == "update" ]; then
	ok=1
	if [ ! -d rootfs ]; then
		errexit "directory rootfs NOT found, abort"	
	fi
	cd rootfs
	echo -n "close: "
	if sudo find . | sudo cpio -o -H newc | gzip > ../rootfs.gz; then
		cd ..
		rm -rf rootfs
	fi
	chown $SUDO_USER.$SUDO_USER rootfs.gz
fi

if [ "$1" == "clean" -o "$1" == "update" ]; then
	ok=1
	rm -rf rootfs
	echo "clean: OK"
fi

if [[ $ok -eq 0 ]]; then
	usage
	exit 1
fi

echo

