#!/bin/bash
#
# (C) 2022 Roberto A. Foglietta, MIT
#

function loopfatresize() {
    set -x
	local loop size=$[$2/1024] ret=1
	loop=$(losetup --show -Pf $1)
	test -b $loop || return 1
	#trap "losetp -d $loop 2>/dev/null || true" EXIT
	if fatresize -i -n 1 ${loop} | grep size: && echo; then
	    echo "Resize VFAT to ${size} Kb"
	    if fatresize -vfs ${size}k -n 1 ${loop} && echo; then
	        if fatresize -i -n 1 ${loop} | grep "Cur size:"; then
	            ret=0
            fi
        fi
    fi
    set +x
	losetup -d $loop
	trap - EXIT
	return $ret
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

cd $wrkdir

if [ "$USER" != "root" ]; then
	if ! timeout 0.2 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	printf "\nRunning '$myname' in '$PWD'\n"
	sudo ./$myname "$@"
	exit $?
fi

errmsg="\n${bld}>>> ${red}ERROR${nrm} in $myname"
errmsg=$errmsg' at line $LINENO, abort.'$nrm'\n\n'
trpcmd='eval "printf \"$errmsg\""'
trap "$trpcmd" ERR

if which pigz >/dev/null; then
    gunzip() { pigz -d "$@"; }
    zcat() { pigz -dc "$@"; }
    gzip() { pigz "$@"; }
fi

size=${1:-256}
tmpl=${2:-128}
skelzext="disk.gz"
skelname="tcl-skeleton"
skellink="$skelname.$skelzext"
skelbase="${skelname}-$tmpl.${skelzext}"
skelfile="${skelname}-${size}.${skelzext}"
disk="$skelname.disk"

function getfilesize() {
    find $1 -printf %s
}

zcat $skelbase >$disk
old_size=$(getfilesize $disk)

new_size=$[(size-1)*1024*1024]
disk_size=$[$new_size+(2048*512)]
dblk_size=$[((disk_size+4095)/4096)*8]

function diskgrowth() {
    local off=2
    { dd if=$1 status=none; dd if=/dev/zero status=none; }|\
        dd bs=512 count=$[$off+$2] conv=notrunc status=none of=$1
    info "Disk resize from $[old_size/1024] kb to $[$off+$2/2] Kb"
}

function diskshrink() {
    local off=1
	dd if=/dev/zero bs=512 seek=$[$off+$2] count=1 status=none of=$1
    info "Disk resize from $[old_size/1024] kb to $[$off+$2/2] Kb"
}

function partbls() {
    printf "\n${bld} \#$2 ${nrm}\n";
    fdisk -l $1 | grep -e $1 -e Device; echo
}

function getvfatsize() {
    local size
    size=$(fatresize -i -n 1 $1 | grep "$2 size:" | cut -d: -f2)
    let size-=2048*512
    echo $size
}

function vfatresize() {
    local loop=$1 size=$2

    from=$(getvfatsize $1 "Cur")
	info "Resize VFAT from $[from/1024] Kb to $[size/1024] Kb\n"

    if fatresize -vfs ${size} -n 1 ${loop}; then
        fatresize -i -n 1 ${loop} || return 1
    fi

    return 0
}

function vfatenlarge() {
    vfatresize $1 $(getvfatsize $1 "Max")
}

function vfatremkpart() {
	printf "d\n n\n \n \n \n \n t\n 6\n a\n w\n" |\
	    fdisk -w never $1 >/dev/null
}

#------------------------------------------------------------------------------#

partbls $disk 1
if [ $new_size -lt $old_size ]; then
	vfatresize $disk $new_size
    partbls $disk 2
    diskshrink $disk $dblk_size
elif [ $new_size -gt $old_size ]; then
	diskgrowth $disk $dblk_size
fi
partbls $disk 3
vfatremkpart $disk
partbls $disk 4
vfatenlarge $disk
partbls $disk 5

#------------------------------------------------------------------------------#

gzip -9c $disk > ${skelfile}
ln -sf ${skelfile} ${skellink}
chownuser ${skellink} ${skelfile}
rm -f $disk

printf "link -> $skellink\n"
txt=$(
    printf "
${bld}Skeleton disk size: $[(dblk_size+2047)/2048] Mb
$skelfile: $(du -ks $skelfile | cut -f1) Kb\n${nrm}
"
); comp "$txt"

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
