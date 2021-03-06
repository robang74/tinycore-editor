#!/bin/ash
#
# Author: Roberto A. Foglietta
#

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

logfile=/var/log/sysinstall.log
showtransfer=no

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

function tag() {
	printf "%3d%% - $2\n" $1
}

myname=$(basename $0)

function usage() {
	echo
	echo "$myname [rootsize] [datadir] destdisk [bootdisk]"
	echo
	return 0
}

function rstdisk_umount_all() {
	sync
	local i mntdir ret=0
	for i in $rstdiskp4 $rstdiskp3 $rstdiskp2 $rstdiskp1; do
		mntdir=$(devdir $i)
		umount $mntdir 2>/dev/null || true
		if grep -qe "^$i " /proc/mounts; then
			mount -o remount,ro $mntdir || true
		fi
		if grep -qe "^$i .* rw," /proc/mounts; then
			ret=$((ret+1))
		fi
	done
	return $ret
}

function alert_exit() {
	if ! usage; then
		tag $1 "$2"
		stage="$3"
	else
		echo "ERROR: $2"
		echo
		trap - EXIT
	fi
	exit 1
}

function atexit() {
	local error lines i errline
	set +ex
	rstdisk_umount_all
	tag  99 "$stage FAILED, abort"
	tag  99 "DEBUG line $1: $(head -n$1 $0 | tail -n1)"
	error=$(grep -v "DEBUG: " $logfile)
	lines=$(echo "$error" | wc -l)
	for i in $(seq 1 $lines); do
		errline=$(echo "$error" | head -n$i | tail -n1)
		tag  99 "DEBUG: $errline"
	done
	tag  99 "DEBUG: $logfile available for inspection"
	tag 100 "FAILED"
	sleep 1
	exit 1
}

function isanumber() {
# busybox grep do not support + in reg expression
	test "$1" == "" && return 1
        echo "$1" | grep -qe "^[0-9]*$"
}

function partready() {
	local part=$(basename $1)
	if ! grep -qe "$part$" /proc/partitions; then
		sleep 1
	fi
	if [ ! -b $1 ]; then
		sleep 1
	fi
	grep -qe "$part$" /proc/partitions
}

function devdir() {
	sed -ne "s,^$1 \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

###############################################################################

if [ "$1" == "-h" -o "$1" == "--help" ]; then
	usage
	exit 0
fi

export datadir=""
export rstdisk=""
export bootdisk=""
export rootsize=24
export rootdir=/mnt/root
export fsfile=system.tgz
export upfile=update.tgz
export upscript=update.sh
export brfile=bootrd.gz

if isanumber "$1"; then
	rootsize=$1
	if [[ $rootsize -lt 10 || $rootsize -ge 27 ]]; then
		alert_exit 0 "Unsuitable size '$1' passed, abort" "Parameters check"
	fi
	shift
fi

if [ "$1" != "" -a -d $1 ]; then
	datadir=$1
	shift
fi
if [ "$1" != "" -a -b $1 ]; then
	rstdisk=$1
	shift
fi
if [ "$1" != "" -a -b $1 ]; then
	bootdisk=$1
	shift
fi

if [ "$1" != "" ]; then
	alert_exit 0 "Unsuitable parameter '$1' passed, abort" "Parameters check"
fi

if [ "$rstdisk" == "" ]; then
	alert_exit 0 "Missing paramter: destdisk, abort" "Parameters check"
fi

if echo "${rstdisk}" | grep -q "mmcblk"; then
	export rstdiskp1=${rstdisk}p1
	export rstdiskp2=${rstdisk}p2
	export rstdiskp3=${rstdisk}p3
	export rstdiskp4=${rstdisk}p4
elif echo "${rstdisk}" | grep -qe "[sh]d[a-z]"; then
	export rstdiskp1=${rstdisk}1
	export rstdiskp2=${rstdisk}2
	export rstdiskp3=${rstdisk}3
	export rstdiskp4=${rstdisk}4
else
	alert_exit 0 "Unespected block device reset:${rstdisk}, abort" "Block devices check"
fi

if [ "$bootdisk" == "" ]; then
	export bootdisk=${rstdisk}
fi

if echo "${bootdisk}" | grep -q "mmcblk"; then
	export bootdiskp1=${bootdisk}p1
	export bootdiskp2=${bootdisk}p2
	export bootdiskp3=${bootdisk}p3
	export bootdiskp4=${bootdisk}p4
elif echo "${bootdisk}" | grep -qe "[sh]d[a-z]"; then
	export bootdiskp1=${bootdisk}1
	export bootdiskp2=${bootdisk}2
	export bootdiskp3=${bootdisk}3
	export bootdiskp4=${bootdisk}4
else
	alert_exit 0 "Unespected block device boot:${bootdisk}, abort" "Block devices check"
fi

tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
dtdev=$(readlink /etc/sysconfig/dtdev)
dtdir=$(readlink /etc/sysconfig/dtdir)
dtdir=${dtdir:-$(devdir $dtdev)}

usbdisk=${tcdev%1}
if [ "$rstdisk" == "$usbdisk" ]; then
	alert_exit 0 "Unsuitable block device usbdisk:${rstdisk}, abort" "Block devices check"
fi

if [ "$datadir" == "" ]; then
	datadir=$dtdir
	if [ "$datadir" == "" ]; then
		alert_exit 0 "Data folder is unavailable, abort" "Data folder check"
	fi
fi

###############################################################################

echo -n "" >$logfile
PS4='DEBUG: $((LASTNO=$LINENO)): '
exec 2>$logfile; set -ex
trap 'atexit $LASTNO' EXIT

tag 1 "Starting data:${datadir}, reset:${rstdisk}, boot:${bootdisk}"

stage="Umount destination block device partitions"
tag 3 "$stage"

rstdisk_umount_all

stage="Check for bootloader and system tarball"
tag 5 "${stage}"

test -f $datadir/$brfile
test -f $datadir/$fsfile

stage="Disk reset and boot record install"
tag 10 "${stage}"

zcat $datadir/$brfile >$rstdisk

if true; then
	echo -e "d\n\n d\n\n d\n\n d\n\n w"
fi | fdisk $rstdisk >/dev/null 2>&1

stage="Disk partitions creation"
tag 20 "${stage}"

if true; then
	echo -e "n\n p\n 1\n \n +${rootsize}G\n N"
	echo -e "n\n p\n 2\n \n +2G\n N"
	echo -e "n\n p\n 3\n \n +2G\n N"
	echo -e "n\n p\n 4\n \n \n N"
	echo -e "t\n 2\n 82\n w"
fi | fdisk $rstdisk >/dev/null 2>&1
sleep 1

for i in $rstdiskp1 $rstdiskp2 $rstdiskp3 $rstdiskp4; do
	partready $i
done

stage="Disk partitions preparation"
tag 30 "${stage}"

if true; then
	mkfs.ext4 -F $rstdiskp1 -L LINUX
	mkswap -L SWAP  $rstdiskp2
	mkfs.ext4 -F $rstdiskp3 -L VARLOG
	mkfs.ext4 -F $rstdiskp4 -L VARDATA
fi >/dev/null

stage="Root filesystem transfer"
tag 40 "${stage}"

mkdir -p $rootdir
mount $rstdiskp1 $rootdir
mkdir -p $rootdir/var/log
mount $rstdiskp3 $rootdir/var/log
mkdir -p $rootdir/var/data
mount $rstdiskp4 $rootdir/var/data

if [ "$showtransfer" == "yes" ]; then
#	set -m
	tar xzf $datadir/$fsfile -mC $rootdir &
	k=0
	n=40
	sleep 1
	while pgrep -x tar >/dev/null; do
		k=$((k+1))
		if [[ $k -ge 30 ]]; then
			k=0;
			n=$((n+5))
			tag $n "${stage}"
		fi
		sleep 1
	done
#	if fg; then true; fi >/dev/null 2>&1
else
	tar xzf $datadir/$fsfile -mC $rootdir
fi

stage="Root filesystem update and configure"
tag 90 "${stage}"

if [ -f $datadir/$upfile ]; then
	tar xzf $datadir/$upfile -moC $rootdir
fi
if [ -f $datadir/$upscript ]; then
	$datadir/$upscript $rootdir
fi

grubcfg=/boot/grub/grub.cfg
newid=$(blkid $rstdiskp1 | sed -e 's,.* UUID="\([^"]*\)" .*,\1,')
setroot=$(grep -e "set=root" $rootdir/$grubcfg | grep -v "hint-bios" | head -n1)
oldid=$(echo $setroot | tr -s ' ' | cut -d' ' -f5)
sed -i "s/$oldid/$newid/g" $rootdir/$grubcfg

echo "
$bootdiskp1 / ext4 defaults 0 0
$bootdiskp2 swap swap defaults 0 1
$bootdiskp3 /var/log ext4 defaults 0 1
$bootdiskp4 /var/data ext4 defaults 0 1
" >$rootdir/etc/fstab 2>/dev/null

stage="Umount destination block device partitions"
tag 95 "${stage}"

rstdisk_umount_all
for i in $rstdiskp4 $rstdiskp3 $rstdiskp1; do
	fsck -yf $i
done >/dev/null 2>&1

trap - EXIT

tag 99 "### REMOVE THE USB KEY AND REBOOT THE SYSTEM ###"
tag 100 "Done."
sleep 1
exit 0

