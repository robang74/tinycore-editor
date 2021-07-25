#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$USER" != "root" ]; then
	echo
	warn "This script requires being root, abort"
	echo
	realexit 1
fi

function realexit() {
	trap - EXIT
	exit $1
}

function atexit() {
	set +xe
	echo
	unmountall
	perr "ERROR: $myname failed at line $1, abort"
	echo
	echo "log file: $logfile"
	echo
	error=$(grep -v "DEBUG: " $logfile)
	lines=$(echo "$error" | wc -l)
	for i in $(seq 1 $lines); do
		errline=$(echo "$error" | head -n$i | tail -n1)
		echo "DEBUG: $errline"
	done
	echo
	realexit 1
}

function devdir() {
	sed -ne "s,$1 on \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

function mountdevdir() {
	mkdir -p $2 2>/dev/null
	test -b "$1" || return 1
	grep -qe "$(basename $1)$" /proc/partitions || return 1
	curdir=$(devdir $tcdev)
	if [ -d "$curdir" ]; then
		mount -o remount,rw $1
		mount --bind $curdir $2
		mount | grep -qe " on $2"
	else
		mount -o rw $1 $2
	fi
}

function unmountall() {
	set +ex
	echo -n "Umounting everything on chroot..."
	umount $rootdir/run
	mount --make-rslave $rootdir/dev
	umount -R $rootdir/dev
	mount --make-rslave $rootdir/sys
	umount -R $rootdir/sys
	umount $rootdir/proc
	umount $rootdir/mnt/tcp2
	umount $rootdir/mnt/tcp1
	umount $rootdir/var/data
	umount $rootdir/var/log
	umount $rootdir
	if mount | grep -qw $rootdir; then
		perr " KO\n"
	else
		comp " OK\n"
	fi
}

function exec2chroot() {
	set +e
	trap - EXIT
	execss=/root/exec2chroot.sh
	script=$rootdir/$execss
	echo "sed -e 's,\\\.,,g' /etc/issue; cd $1; $2" > $script
	chmod a+x $script
	chroot $rootdir $execss 2>&3
	rm -f $script
	unmountall
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

function usage() {
	echo
	warn "USAGE: $myname [run script] device"
	echo
}

###############################################################################

rootdir=/mnt/root
myname=$(basename $0)
logfile=/var/log/dev2chroot.log
runopts=rw,nosuid,noexec,relatime,size=40960k,mode=755
homedir=/home/lubuntuq7

if [ "$1" == "-h" -o "$1" == "--help" ]; then
	usage; realexit 1
fi

script=""
if [ "$1" == "run" ]; then
	script=$2
	if [ ! -f "$script" ]; then
		usage; realexit 1
	fi
	shift 2
fi

blkdev=$1
if [ "$blkdev" == "" ]; then
	blkdev=/dev/mmcblk1
fi
if [ ! -b $blkdev ]; then
	usage; realexit 1
fi

###############################################################################

PS4='DEBUG: $((LASTNO=$LINENO)): '
exec 3>&2 2>$logfile; set -ex
trap 'atexit $LASTNO' EXIT

if mount | grep -qe " on $rootdir "; then
	echo
	perr "The $rootdir is just mounted, abort"
	echo
	exit 1
fi

if echo "${blkdev}" | grep -q "mmcblk"; then
	export blkdevp1=${blkdev}p1
	export blkdevp2=${blkdev}p2
	export blkdevp3=${blkdev}p3
	export blkdevp4=${blkdev}p4
elif echo "${blkdev}" | grep -qe "[sh]d[a-z]"; then
	export blkdevp1=${blkdev}1
	export blkdevp2=${blkdev}2
	export blkdevp3=${blkdev}3
	export blkdevp4=${blkdev}4
else
	echo
	perr "ERROR: Unespected block device ${blkdev}, abort"
	echo
	realexit 1
fi

echo -n "Mounting: ROOT"
mountdevdir $blkdevp1 $rootdir
if mountdevdir $blkdevp3 $rootdir/var/log; then
	echo -n " LOG"
fi
if mountdevdir $blkdevp4 $rootdir/var/data; then
	echo -n " DATA"
fi

conffile="$rootdir/$homedir/conf/modulename.conf"
if grep -qe "NVR" -e "CMS" $conffile; then
	if mountdevdir /dev/sda1 $rootdir/opt; then
		echo -n " OPT"
	fi
fi

tcdev=$(blkid | grep -e "=.TINYCORE. " | cut -d: -f1)
ntdev=$(echo $tcdev | sed -e "s,1$,2,")
if mountdevdir $tcdev $rootdir/mnt/tcp1; then
	echo -n " TCP1"
fi
if mountdevdir $ntdev $rootdir/mnt/tcp2; then
	echo -n " TCP2"
fi

echo -n " PROC"
mount -t proc proc $rootdir/proc
echo -n " SYS"
mount --rbind /sys $rootdir/sys
echo -n " DEV"
mount --rbind /dev $rootdir/dev
echo -n " RUN"
mount -t tmpfs -o $runopts tmpfs $rootdir/run
echo

echo
comp "chroot in $rootdir"
echo
exec2chroot /root /bin/bash
