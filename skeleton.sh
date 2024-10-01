#!/bin/bash
#
# (C) 2022 Roberto A. Foglietta, MIT
#

function diskfatresize() {
	local loop size=$[$2/1024]
	loop=$(losetup --show -Pf $1)
	test -b $loop || exit 1
	trap "losetp -d $loop 2>/dev/null" EXIT
	fatresize -i -n 1 ${loop} | grep size:;	echo
	fatresize -vfs ${size}k -n 1 ${loop}; echo
	fatresize -i -n 1 ${loop} | grep "Cur size:"
	losetup -d $loop
	trap - EXIT
}

function chownuser() {
	local user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

nrm="\x1b[0m"
bld="\x1b[1m"
red="\x1b[41m"

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

set -e #########################################################################

export myname=${myname:-$(basename $0)}
export wrkdir=${wrkdir:-$(dirname $0)}

errmsg="\n${bld}>>> ${red}ERROR${nrm} in $myname"
errmsg=$errmsg' at line $LINENO, abort.'$nrm'\n\n'
trpcmd='eval "printf \"$errmsg\""'
trap "$trpcmd" ERR

if [ "$USER" != "root" ]; then
	if ! timeout 0.2 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	cd $wrkdir
	sudo ./$myname "$@"
	exit $?
fi

if which pigz >/dev/null; then
    gunzip() { pigz -d "$@"; }
    zcat() { pigz -dc "$@"; }
    gzip() { pigz "$@"; }
fi

size=${1:-256}
disk=${size}MB.disk

skelzext="disk.gz"
skelname="tcl-skeleton"
skellink="$skelname.$skelzext"
skelbase="${skelname}-35.${skelzext}"
skelfile="${skelname}-${size}.${skelzext}"

zcat $skelbase >$disk
old_size=$(du -b $disk | cut -f1)

new_size=$[size*1024*1000]
disk_size=$[new_size+(2048*512)]
dblk_size=$[((new_size+511)/512)+2048]

if [ $new_size -lt $old_size ]; then
	diskfatresize $disk $new_size
	#qemu-img resize --shrink -f raw $disk $disk_size
	dd if=/dev/zero seek=$dblk_size count=1 of=$disk
elif [ $new_size -gt $old_size ]; then
	#qemu-img resize -f raw $disk $disk_size
	dd if=/dev/zero seek=$dblk_size count=1 of=$disk
	echo -e "d\n n\n \n \n \n \n t\n b\n a\n w\n" |\
	    tr -d ' ' | fdisk $disk
	diskfatresize $disk $new_size
fi

gzip -9c $disk > ${skelfile}
ln -sf ${skelfile} ${skellink}
chownuser ${skellink} ${skelfile}
rm -f $disk

printf "link -> $skellink\n\n$bld"
echo "Skeleton disk size: ${size} Mb"
du -ks $skelfile | tr '\t' ' '
printf "${nrm}\n"

exit 0 ###################################################
#
# syslinux complains about geometry in some distributions
#
##########################################################

#dd if=/dev/zero bs=1M count=${size} of=$disk
img_size=$[size*1024*1024]
# bytes per sector
bytes=512
# sectors per track
sectors=63
# heads per track
heads=255
# bytes per cylinder is bytes*sectors*head
bpc=$[bytes*sectors*heads]
# number of cylinders
cylinders=$[$img_size/$bpc]
# rebound the size
img_size=$[$cylinders*$bpc]
qemu-img create -f raw $disk $img_size
#dd if=/dev/zero count=$[img_size/512] of=$disk
echo -e "n\n \n \n \n \n t\n b\n a\n w" |\
	fdisk -H $heads -S $sectors -C $cylinders $disk
loop=$(losetup -f)
losetup -P $loop $disk
mkfs.vfat ${loop}p1
mkdir -p tmp
mount ${loop}p1 tmp
tar xvzf tcl-boot-syslinux.tgz -moC tmp
sed -i "s,vga=771,vga=791," tmp/boot/syslinux/syslinux.cfg
umount tmp
syslinux -H $heads -S $sectors -d /boot/syslinux -i ${loop}p1 || true
zcat tcl-usb-boot-enable.gz >$loop
sync 
losetup -d $loop
gzip -9c $disk >${skelname}-${size}.${skelzext}
ln -sf ${skelname}-${size}.${skelzext} ${skelname}.${skelzext}
chown $SUDO_USER.$SUDO_USER ${skelname}-${size}.${skelzext}
chown $SUDO_USER.$SUDO_USER -h ${skelname}.${skelzext}
ls -1l ${skelname}.${skelzext}
rm -f $disk
