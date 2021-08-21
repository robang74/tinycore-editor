#!/bin/bash
#
# Author: Roberto A. Foglietta
#

function usage() {
	echo
	echo "USAGE: $myname [open|close|update|clean|distclean]"
	echo
}

function errexit() {
	echo
	echo "ERROR: $1"
	echo
	exit 1
}

function chownuser() {
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

ok=0
if [ "$USER" != "root" ]; then
	sudo $0 "$@"
	exit $?
fi

tmpdir=rootfs.tmp
myname=$(basename $0)
cd $(dirname $0)
WRKDIR="$PWD"

source tinycore.conf

echo
echo "Working folder is $WRKDIR"

if [ "$1" == "open" -o "$1" == "update" ]; then
	ok=1
	if [ -d $tmpdir ]; then
		echo "opened folder: $tmpdir"
		echo
		exit 0
	fi
	mkdir $tmpdir
	cd $tmpdir
	echo -n "open data: "
	zcat ../rootfs.gz | sudo cpio -i -H newc -d 2>&1
	cat ../changes/rcS > etc/init.d/rcS
	cat ../changes/tce-load > usr/bin/tce-load
	cat ../changes/tc-functions > etc/init.d/tc-functions
	echo "$tczmeta" | grep -w "develop" >etc/sysconfig/devel
	test -e lib64 || ln -sf lib lib64
	echo "opened folder: $tmpdir"
	cd ..
fi

if [ "$1" == "close" -o "$1" == "update" ]; then
	ok=1
	if [ ! -d $tmpdir ]; then
		errexit "directory $tmpdir NOT found, abort"
	fi
	cd $tmpdir
	echo -n "close data: "
	echo "$tczmeta" | grep -w "develop" >etc/sysconfig/devel
	if sudo find . | sudo cpio -o -H newc | gzip > ../rootfs.gz; then
		cd ..
		rm -rf $tmpdir
	fi
	if which advdef >/dev/null; then
		advdef -z3 rootfs.gz
		rm -f rootfs.gz.tmp*
	else
		echo "Install advdef to compress further the rootfs.gz"
	fi
	chownuser rootfs.gz
fi

if [ "$1" == "clean" -o "$1" == "update" -o "$1" == "distclean" ]; then
	ok=1
	rm -rf $tmpdir
	echo "clean: OK"
fi

if [ "$1" == "distclean" ]; then
	ok=1
	rm -rf rootfs.gz
	echo "distclean: OK"
fi

if [[ $ok -eq 0 ]]; then
	usage
	exit 1
fi

echo

