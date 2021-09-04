#!/bin/bash
#
# Author: Roberto A. Foglietta
#

function usage() {
	echo
	echo "USAGE: $myname [chroot|open|close|update|clean|distclean]"
	echo
}

function errexit() {
	echo
	echo "ERROR: $1"
	echo
	exit 1
}

function chownuser() {
	local user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function setp2type() {
	if echo "$tczmeta" | grep -qw "develop"; then
		echo ext4
	else
		echo ntfs
	fi >etc/sysconfig/p2type
}

function chroot_atexit() {
	umount $tmpdir.bash 2>/dev/null || true
	rm -rf $WRKDIR/$tmpdir.bash
	rm -rf $WRKDIR/$tmpdir
	echo
	echo "chroot clean: OK"
	echo
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

tczlist="bash readline ncursesw dropbear"

ok=0
if [ "$USER" != "root" ]; then
	sudo $0 "$@"
	exit $?
fi

tmpdir=rootfs.tmp
myname=$(basename $0)
cd $(dirname $0)
WRKDIR="$PWD"

if [ ! -e tinycore.conf ]; then
	source tinycore.conf.orig
else
	source tinycore.conf
fi

if [ "$1" == "chroot" ]; then
	trap 'printf "\nERROR at line $LINENO, abort\n\n"' ERR
	trap "chroot_atexit" EXIT
	set -e
	./$myname open
	tar xzf tccustom$tcsize.tgz -moC $tmpdir

	echo
	echo "gsettings for avoid automount windows displaying..."
	prev=$(su -l $SUDO_USER -c "gsettings get org.gnome.desktop.media-handling automount-open 2>/dev/null")
	su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open false 2>/dev/null"
	echo

	tmptczdir=$tmpdir.tcz
	mkdir $tmptczdir
	for i in $tczlist; do
		mount tcz/$i.tcz $tmptczdir
		for i in bin lib; do
			for j in . usr usr/local; do
				if [ -d $tmptczdir/$j/$i ]; then
					cp -arf $tmptczdir/$j/$i $tmpdir
				fi
			done
		done
		umount $tmptczdir
	done
	rm -rf $tmptczdir

	su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open $prev 2>/dev/null"

	cd $tmpdir
	rm -f etc/sysconfig/p2type
	tar czf ../chrootfs.tgz .
	cd ..
	if which advdef >/dev/null; then
		advdef -z3 chrootfs.tgz
		rm -f chrootfs.tgz.tmp*
	else
		echo "Install advdef to compress further the chrootfs.tgz"
	fi
	chownuser chrootfs.tgz
	exit 0
fi

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
	if [ -e ../changes/tce-setup ]; then
		cat ../changes/tce-setup > usr/bin/tce-setup
	fi
	setp2type
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
	rm -rf $tmpdir
	rm -rf rootfs.gz
	rm -rf chrootfs.tgz
	echo "distclean: OK"
fi

if [[ $ok -eq 0 ]]; then
	usage
	exit 1
fi

echo

