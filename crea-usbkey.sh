#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function perr() {
	echo "$@" >&2
}

function usage() {
	echo
	echo "usage: $(basename $0) [-y] image.disk[.gz] /dev/blockdev"
	echo
}

#function rrdiskptbl() {
#	dev=$1
#	hdparm -z $dev >/dev/null
#	disk=$(echo $dev | sed -e "s,/dev/,,")
#	echo 1 > /sys/block/$disk/device/rescan
#}

if [ "$1" == "-y" ]; then
	shift
	ans="y"
fi

if [ "$#" != "2" ]; then
	usage; exit 1
fi
if [ ! -e "$1" ]; then
	perr "Error: the specified image file does not exist, abort."
	usage; exit 1
fi
if [ ! -b "$2" ]; then
	perr "Error: the specified block device does not exist, abort."
	usage; exit 1
fi

disk="$2"
image=""
zimage=""

if file "$1" | grep -q "gzip compressed data"; then
	if ! zcat "$1" | file - | grep -q "DOS/MBR boot sector"; then
		perr "Error: specified file is not a bootable image"
	fi
	zimage="$1"
else
	if ! file "$1" | grep -q "DOS/MBR boot sector"; then
		perr "Error: specified file is not a bootable image"
	fi
	image="$1"
fi

if [ "$(whoami)" != "root" ]; then
	echo "This script requires root priviledges, uprising..."
	if [ "$ans" == "y" ]; then
		sudo $0 -y "$@"
	else
		sudo $0 "$@"
	fi
	exit $?
fi

echo
if [ "$zimage" != "" ]; then
	echo "Image $zimage: compressed"
else
	echo "Image $image: $(du -m $image | cut -f1)MiB"
fi
fdisk -l $disk | grep "Disk $disk:" | cut -d, -f1

if [ "$ans" != "y" ]; then
	echo
	echo -n "This will destroy every data in $disk, continue? [y/N] "
	read ans
	if [ "$ans" != "y" -a "$ans" != "Y" ]; then
		echo "Abort."
		exit 0
	fi
fi

echo
echo -n "Umounting block device partitions..."
for i in $disk?; do
	umount $i 2>/dev/null
	if mount | grep -q $i; then
		echo " KO"; exit 1
	fi
done
echo " OK"

echo -n "Image transfer to block device..."
if [ "$zimage" != "" ]; then
	if ! zcat $zimage >$disk; then
		echo " KO"; exit 1
	fi
else
	if ! cat $image >$disk; then
		echo " KO"; exit 1
	fi
fi
sync
echo " OK"

echo -n "Creation the extra partition..."
echo -e "n\np\n2\n\n\nN\nt\n2\n7\nw" | fdisk $disk >/dev/null 2>&1
part=$(fdisk -l $disk | grep -e "^$disk[^ 0123456789]*2 " | cut -d' ' -f1)
if [ "$part" == "" ]; then
	echo " KO"; exit 1
fi
echo " OK"
sleep 1
echo
echo "Formatting the extra partition..."
mkfs -t ntfs -F -Q $part
echo

mdir=/mnt/usbk2
mkdir -p $mdir
mount $part $mdir
echo -n "Files transfer to extra partition..."
if [ "$zimage" != "" ]; then
	cp $zimage $mdir
else
	gzip -c $image >$mdir/$image.gz
fi
rufus=$(ls -1 rufus*.exe | tail -n1)
if [ -f $rufus ]; then
	cp $rufus $mdir
fi
cp -arf GPG system.tgz xserver-*.tgz xmaps-*.tgz $mdir 2>/dev/null
mkdir -p $mdir/GPG
cp $0 $mdir
echo " OK"

echo -n "Check the files transfer to extra partition..."
echo >$mdir/completed.txt
if [ ! -e $mdir/completed.txt ]; then
	umount $mdir
	echo " KO"; exit 1
fi
rm -f $mdir/completed.txt
umount $mdir
echo " OK"

echo
echo "USB key created successfully"

