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

function umountdir() {
	local i
	for i in {1..5}; do
		umount $1 2>/dev/null || true
		grep -q "$1" /proc/mounts || break
		sleep 1
	done
	grep -vq "$1" /proc/mounts
}

function chroot_atexit() {
	set +e
	umountdir $tmptczdir
	rm -rf $WRKDIR/$tmptczdir
	rm -rf $WRKDIR/$tmpdir
	echo
	echo "chroot clean: OK"
	echo
}

function info() {
        echo -e "\e[1;36m$@\e[0m"
}

function comp() {
        echo -e "\e[1;32m$@\e[0m"
}

function warn() {
        echo -e "\e[1;33m$@\e[0m"
}

function perr() {
        echo -e "\e[1;31m$@\e[0m"
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

tczlist="bash readline ncursesw dropbear kmaps"

ok=0
tmpdir=rootfs.tmp
tmptczdir=$tmpdir.tcz
myname=$(basename $0)
cd $(dirname $0)
WRKDIR="$PWD"


if [ "$1" != "close" -a "$1" != "distclean"  ]; then
	if [ ! -r rootfs.gz ]; then
		echo
		perr "ERROR: file tinycore/rootfs.gz does not exist"
		echo
		warn "SUGGEST: run tinycore/provides/tcgetdistro.sh"
		echo
		exit 1
	fi
fi

if [ "$USER" != "root" ]; then
	if ! timeout 0.2 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	sudo ./$myname "$@"
	exit $?
fi

if [ ! -e tinycore.conf ]; then
	cp -f tinycore.conf.orig tinycore.conf
	chownuser tinycore.conf
fi
source tinycore.conf

if [ "$1" == "chroot" ]; then
	trap 'printf "\nERROR at line $LINENO, abort\n\n"' ERR
	trap "chroot_atexit" EXIT
	set -e

	../busybox/busybox.sh update
	./$myname open
	mkdir -p $tmpdir/etc/ssh/users
	cp -arf ../sshkeys.pub/*.pub $tmpdir/etc/ssh/users
	cat changes/rcS.chroot >$tmpdir/etc/init.d/rcS
	tar xzf changes/sshdhostkeys.tgz -moC $tmpdir/etc/ssh
	tar xzf tccustom$tcsize.tgz -moC $tmpdir

	for i in dev2chroot.sh reboot.sh shutdown.sh uskb.sh ??kb.sh; do
		cp -f changes/$i $tmpdir/bin
		chmod a+x $tmpdir/bin/$i
	done
	echo "cd; sudo -s" >$tmpdir/bin/broot
	chmod a+x $tmpdir/bin/broot
	head -n5 $tmpdir/etc/motd >$tmpdir/etc/motd.new
	mv -f $tmpdir/etc/motd.new $tmpdir/etc/motd
	echo tc >$tmpdir/etc/sysconfig/tcuser
	touch $tmpdir/etc/sysconfig/superuser
	grep -v tc-functions $tmpdir/home/tc/.ashrc >$tmpdir/etc/profile.d/alias.sh
	rm -f $tmpdir/root/.ashrc $tmpdir/home/tc/.ashrc

	echo
	echo "gsettings for avoid automount windows displaying..."
	prev=$(su -l $SUDO_USER -c "gsettings get org.gnome.desktop.media-handling automount-open 2>/dev/null")
	su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open false 2>/dev/null"
	echo

	mkdir $tmptczdir
	for i in $tczlist; do
		echo "Integrating $i.tcz..."
		mount tcz/$i.tcz $tmptczdir
		for k in bin lib; do
			for j in . usr usr/local; do
				if [ -d $tmptczdir/$j/$k ]; then
					cp -arf $tmptczdir/$j/$k $tmpdir
				fi
			done
		done
		if [ -d $tmptczdir/usr/share ]; then
			mkdir -p $tmpdir/usr/share
			cp -arf $tmptczdir/usr/share $tmpdir/usr
		fi
		if [ -d $tmptczdir/usr/local/share ]; then
			mkdir -p $tmpdir/usr/local/share
			cp -arf $tmptczdir/usr/local/share $tmpdir/usr/local
		fi
		if [ -d $tmptczdir/usr/local/tce.installed ]; then
			cp -arf $tmptczdir/usr/local/tce.installed $tmpdir/usr/local
		fi
		umountdir $tmptczdir
	done
	mkdir -p $tmpdir/usr/local/bin/
	ln -sf /bin/dropbearmulti $tmpdir/usr/local/bin/dropbearmulti
	rm -rf $tmptczdir

	su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open $prev 2>/dev/null"

	echo
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
	set -e
	test -f rootfs.gz
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
	for i in root home/tc; do
		mkdir -p $i
		cat ../changes/ashrc >$i/.ashrc
	done
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

