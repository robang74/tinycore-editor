#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#
  
myip=10.0.2.15
brip=10.0.2.16
tcip=10.0.2.17
netm=24
ARCH=x86_64 #i386
qemuexec=qemu-system-$ARCH
tcdir="" #if not defined, it will be found
devloop="" #if not defined, it will be found
drvi8gb="format=raw,file=tcl-8Gb-usb.disk"
drvboot="format=raw,file=tcl-64Mb-usb.disk"
drvdata="id=sd,if=none,bus=1,unit=0,format=raw,file=storage-32Gb.disk"
tcldir="tcldisk"

if [ -e make.conf ]; then
	source make.conf
fi

targets="
open
qemu-init
qemu-test
qemu
ssh-root
ssh-copy
ssh-end
qemu-stop
close
clean
all
image
"

copylist="
tinycore/tcz:
tinycore/flags:
tinycore/tinycore.conf:provides/
tinycore/provides/*.sh:provides/
tinycore/changes/afterboot.sh:
tinycore/changes/{*.sh,*.tgz}:custom/
tinycore/changes/syslinux.cfg:boot/syslinux/
tinycore/changes/boot.msg:boot/syslinux/
crea-usbkey.sh:custom/usbcreate.sh
tinycore/vmlinuz:boot/
tcl-usb-boot-*able.gz:
sshkeys.pub:
"

cd $(dirname $0)
myname="$(basename $0)"
param="$1"
option="$2"
shift
shift

###############################################################################

function isanipaddr() {
	echo "$1" | grep -qe "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"
}

function usage() {
	echo
	info " USAGE: $myname target"
	echo
	echo -e "\ttargets:"
	echo -e "\t\topen | image [8Gb]"
	echo -e "\t\tqemu-init"
	echo -e "\t\tqemu-test"
	echo -e "\t\tqemu [8Gb]"
	echo -e "\t\tssh-copy [ip]"
	echo -e "\t\tssh-end [8Gb]"
	echo -e "\t\tqemu-stop"
	echo -e "\t\tclose"
	echo -e "\t\tclean"
	echo -e "\t\tall [8Gb]"
	echo -e "\t\tssh-root [ip]"
	echo
}

function realexit() {
	trap - EXIT
	exit $1
}

function atexit() {
	trap - EXIT
	set +e
	echo
	perr "ERROR: $myname $param failed with error"
	if [  "$warning" != "" ]; then
		echo
		warn "$warning"
	fi
	echo
	exit 1
}

function myssh() {
	if [[ $1 -eq 0 ]]; then
		tout=1000d
	else
		tout=$1
	fi
	shift 1
	if [ "$1" == "root" ]; then
		user="root"
		pass="root"
	elif [ "$1" == "tc" ]; then
		user="tc"
		pass=$tcpassword
	else
		exit 1
	fi
	shift 1
	su -m $SUDO_USER -c "exec -a myssh timeout $tout sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$tcip \"$@\""
}

function myscp() {
	if echo -- "$@" | grep -q "root@"; then
		pass="root"
	elif echo -- "$@" | grep -q "tc@"; then
		pass=$tcpassword
	else
		exit 1
	fi
	su -m $SUDO_USER -c "sshpass -p $pass scp -o StrictHostKeyChecking=no -r $*"
}

function waitforssh() {
	info "executing: waitforssh"
	k=0
	sleep 1
	while ! myssh 1 tc "whoami" | grep -qw "tc"; do
		if ! pgrep qemu; then
			return 1
		fi >/dev/null
		k=$[k+1]
		sleep 1
	done 2>/dev/null
	return 0
}

function tcrootunlock() {
	tcsshdconfig=/usr/local/etc/ssh/sshd_config
	if myssh 0 tc "sudo unlock.sh;
		grep -qe '^PermitRootLogin yes' $tcsshdconfig || \
			(sudo root-ssh.sh && echo DONE)" | grep -wq "DONE"; then
		waitforssh
	fi
}

function tcdircopy() {
	src=$(echo "$1" | cut -d: -f1)
	dst=$(echo "$1" | cut -d: -f2)
	eval sudo cp -rf $src $tcldir/$dst && \
		echo -e "\ttransfer $1" | sed "s,:, -> $tcdir/,"
}

function tccopyall() {
	test -n "$tcldir"
	mkdir -p $tcldir/flags
	mkdir -p $tcldir/custom
	mkdir -p $tcldir/provides
	mkdir -p $tcldir/boot/syslinux
	for i in $copylist; do 
		tcdircopy $i
	done
	cat tinycore/{rootfs.gz,modules.gz} > $tcldir/boot/core.gz
	echo -e "\ttransfer tinycore/{rootfs.gz,modules.gz} -> $tcldir/boot/core.gz"	
	sync
}

function getfreeloop() {
	declare -i n
	loops=$(losetup -a | cut -d: -f1) 
	n=$(echo "$loops" | tr -cd [0-9]\\n | sort -n | tail -n1)	
	echo $[n+1]
}

function sshgettcdir() {
	test "$tcdir" != "" && return 0
	tcdir=$(myssh 0 root tcldevdir.sh | cut -d: -f2)
	test "$tcdir" != ""
}

function sshfingerprintclean() {
	if [ "$sshkeycln" == "yes" ]; then
		if [ ! -d ~/.ssh ]; then
			yes "" | su -l $SUDO_USER -c "ssh-keygen"
		fi 2>/dev/null
		if [ -e ~/.ssh/known_hosts ]; then
			su -l $SUDO_USER -c "ssh-keygen -R $tcip"
		fi
		sshkeycln=no
	fi >/dev/null
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

eval $(grep -e "tcpassword=" tinycore/changes/afterboot.sh | head -n1)
if [ "$tcpassword" == "" ]; then
	echo
	perr "ERROR: tcpassword is not defined in tinycore/changes/afterboot.sh"
	echo
	exit 1
elif [ "$tcpassword" != "tinycore" ]; then
	echo
	warn "WARNING: standard password for user tc is changed, check it out"
	echo "         please check tinycore/changes/root-ssh.sh"
	echo "         please check tinycore/changes/tccustom.tgz:/etc/motd"
	echo
fi

if [ "$USER" != "root" ]; then
	set -m
	if ! timeout 0.1 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	sudo $0 $param $option
	exit $?
fi

if [ "$param" == "ssh-copy" -o  "$param" == "ssh-root" ]; then
	if isanipaddr $option; then
		tcip=$option
		option=""
	fi
fi

if [ "$1" != "" ]; then
	usage; exit 1
fi

if [ "$option" != "8Gb" -a "$option" != "" ]; then
	usage; exit 1
fi

ok=0
for i in $targets; do
	if [ "$i" == "$param" ]; then
		ok=1
		break;
	fi
done
if [ "$ok" != "1" ]; then
	usage; exit 1
fi

if [ "$devloop" == "" ]; then
	devloop="/dev/loop$(getfreeloop)"
fi

###############################################################################

trap 'atexit' EXIT

set -e

sshkeycln=yes
warning=""
echo
if [ "$param" == "all" ]; then
	info "executing: $myname $param"
fi

if [ "$param" == "open" -o "$param" == "all" ]; then
	info "executing: open"
	if [ -e tcl-64Mb-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk images"
		exit 1
	fi
	if [ ! -e storage-32Gb.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32Gb.disk
	fi
	zcat tcl-64Mb-usb.disk.gz >tcl-64Mb-usb.disk
	chown $SUDO_USER.$SUDO_USER *.disk
	sync
fi

if [ "$param" == "all"   -a "$option" == "8Gb" ] \
|| [ "$param" == "image" -a "$option" == "8Gb" ]; then
	info "executing: image 8Gb"
	if [ -e tcl-8Gb-usb.disk ]; then
		warning="SUGGEST: run 'rm -f tcl-8Gb-usb.disk' to remove existing disk"
		exit 1
	fi
	if [ ! -e tcl-64Mb-usb.disk.gz -a ! -e tcl-64Mb-usb.disk ]; then
		warning="SUGGEST: run '$myname image' to create the 64Mb disk image"
		exit 1		
	fi
	dd if=/dev/zero bs=1M count=1 seek=7500 of=tcl-8Gb-usb.disk
	if [ -e tcl-64Mb-usb.disk ]; then
		dd if=tcl-64Mb-usb.disk bs=1M of=tcl-8Gb-usb.disk conv=notrunc
	else
		zcat tcl-64Mb-usb.disk.gz | dd bs=1M of=tcl-8Gb-usb.disk conv=notrunc
	fi
	if [ "$param" == "image" ]; then
		losetup --partscan $devloop tcl-8Gb-usb.disk
		if true; then
			echo -e "n\n p\n 2\n \n \n N"
			echo -e "t\n 2\n 7\n w"
		fi | fdisk $devloop >/dev/null 2>&1
		mkfs -t ntfs -L NTFS -F -Q ${devloop}p2 >/dev/null
		losetup -D $devloop
	fi
	chown $SUDO_USER.$SUDO_USER tcl-8Gb-usb.disk
	sync
fi

stayalive=no
if [ "$param" == "qemu-init" -o "$param" == "all" ]; then
	info "executing: qemu-init"
	if ! ifconfig brkvm 2>/dev/null | grep -q "inet "; then
		sudo brctl addbr brkvm
		sudo ip addr add $brip/$netm dev brkvm
		sudo ip link set brkvm up
		sudo mkdir -p /etc/qemu
		sudo touch /etc/qemu/bridge.conf
		echo "allow brkvm" | sudo tee /etc/qemu/bridge.conf
		sudo dnsmasq --interface=brkvm --bind-interfaces --dhcp-range=$tcip,$tcip
		sshfingerprintclean
	else
		stayalive=yes
	fi
fi

function killsshafterqemu() {
	while sleep 0.5; do
		if pgrep qemu; then
			break;
		fi >/dev/null
	done
	while sleep 0.5; do
		if ! pgrep qemu; then
			pkill -f myssh
			break;
		fi >/dev/null 2>&1
	done
}

if [ "$param" == "qemu-test" ]; then
	if [ ! -f tcl-64Mb-usb.disk ]; then
		$0 image
	fi
	if [ "$option" == "8Gb" ]; then
		$0 image $option
	fi
	$0 qemu-init && time $0 qemu $option \
		&& $0 ssh-root || realexit 1
fi

if [ "$param" == "qemu" -o "$param" == "all" ]; then
	info "executing: qemu $option"
	if [ ! -e storage-32Gb.disk -o ! -e tcl-64Mb-usb.disk ]; then
		warning="SUGGEST: target open or image to deploy the disk images"
		exit 1
	fi
	if ! ifconfig brkvm 2>/dev/null | grep -q "inet "; then
		warning="SUGGEST: target qemu-init to uprise the enviroment"
		exit 1
	fi
	if pgrep qemu >/dev/null; then
		warning="SUGGEST: qemu is just running, use it or kill it"
		exit 1
	fi
	if [ "$option" == "8Gb" ]; then
		info "executing: qemu will boot from the 8Gb image"
		drvboot=$drvi8gb
	fi
	sudo $qemuexec --cpu host --enable-kvm -m 256 -boot c -net nic \
		-net bridge,br=brkvm -drive $drvboot -device sdhci-pci \
		-device sdhci-pci -device sd-card,drive=sd -drive $drvdata &

	info "executing: waiting for the qemu system start-up"
	sshfingerprintclean
	waitforssh
fi

if [ "$param" == "ssh-root" ]; then
	info "executing: ssh $tcip"
	sshfingerprintclean
	killsshafterqemu >/dev/null 2>&1 &
	tcrootunlock
	set +e
	myssh 0 root
	info "executing: ssh-root $tcip completed"
	trap - EXIT
	exit 0
fi

if [ "$param" == "ssh-copy" -o "$param" == "all" ]; then
	info "executing: ssh-copy $tcip"
	if [ -e "$tcldir" ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk folder"
		exit 1
	fi
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	tccopyall
	cd $tcldir
	chown -R $SUDO_USER.$SUDO_USER .
	myssh 0 root "tcz2tce.sh back"
	myscp * root@$tcip:$tcdir && \
		echo -e "\ttransfer everything to $tcip:$tcdir"
	myssh 0 root "test -e $tcdir/tce && tcz2tce.sh >/dev/null; sync"
	cd ..
	rm -rf $tcldir
fi

if [ "$param" == "image" -a "$option" != "8Gb" ]; then
	info "executing: image"
	if [ -e tcl-64Mb-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk images"
		exit 1
	fi
	if [ ! -e storage-32Gb.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32Gb.disk
	fi
	zcat tcl-64Mb-skeleton.disk.gz >tcl-64Mb-usb.disk
	sync

	sudo losetup --partscan $devloop tcl-64Mb-usb.disk
	if ! sudo fsck -fy ${devloop}p1; then
		sudo fsck -fy ${devloop}p1
	fi
	eval $(grep "tclabel=" tinycore/changes/rcS)
	if ! blkid  --label $tclabel $devloop; then
		echo
		warn "WARNING: in rcS the label is '$tclabel' but not in the image"
		rm -f tcl-64Mb-usb.disk
		sudo losetup -D $devloop
		exit 1
	fi
	mkdir -p $tcldir
 	if ! sudo mount -o rw ${devloop}p1 $tcldir; then
		rm -f tcl-64Mb-usb.disk
		sudo losetup -D $devloop
		rmdir $tcldir
		exit 1		
	fi
	tccopyall
	sudo dd if=/dev/zero of=$tcldir/zero >/dev/null 2>&1 || true
	sync; sudo rm -f $tcldir/zero $tcldir/FSCK????.REC; sync
	k=0; sleep 1
	while ! sudo umount $tcldir; do
		[[ $k -lt 5 ]]
		k=$[k+1]
		sleep 1
	done 2>/dev/null
	sudo losetup -D $devloop
	chown $SUDO_USER.$SUDO_USER *.disk
	rmdir $tcldir

fi

if [ "$param" == "ssh-end" -o "$param" == "all" ]; then
	info "executing: ssh-end $option"
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	if [ "$option" == "8Gb" ]; then
		myssh 0 root "ntfs-usbdisk-partition-create.sh && echo DONE" | grep -q DONE
	fi
	myssh 0 root "dd if=/dev/zero of=$tcdir/zero; sync; rm -f $tcdir/zero; shutdown"
	info "executing: waiting for the qemu system shut down"
	k=0
	sleep 1
	while myssh 1 tc "whoami" >/dev/null 2>&1; do
		pgrep qemu >/dev/null
		k=$[k+1]
		if [[ $k -gt 10 ]]; then
			myssh 10 root "shutdown.sh" || true
			pgrep qemu >/dev/null && exit 1
			exit 0
		fi
		sleep 1
	done
	while pgrep qemu >/dev/null; do sleep 1; done
fi

if [ "$param" == "qemu-stop" -o "$param" == "all" ]; then
	info "executing: qemu-stop"
	if pgrep qemu >/dev/null; then
		warning="SUGGEST: qemu is just running, use it or kill it"
		exit 1
	fi
	if [ "$stayalive" != "yes" ]; then
		set +e
		sudo killall dnsmasq
		sudo ip link set brkvm down
		sudo ip addr del $brip/$netm dev brkvm
		sudo brctl delbr brkvm
		set -e
	fi
fi

if [ "$param" == "close" -o "$param" == "all" ]; then
	nclosed=0
	info "executing: close"
	if [ -e tcl-64Mb-usb.disk ]; then
		gzip -9c tcl-64Mb-usb.disk >tcl-64Mb-usb.disk.gz
		let nclosed++ || true
	fi
	if [ -e tcl-8Gb-usb.disk ]; then
		gzip -9c tcl-8Gb-usb.disk >tcl-8Gb-usb.disk.gz
		let nclosed++ || true
	fi
	chown $SUDO_USER.$SUDO_USER *.disk.gz
	if [[ $nclosed -lt 1 ]]; then
		warning="SUGGEST: do it manually or clean"
		exit 1
	fi
fi

if [ "$param" == "clean" -o "$param" == "all" ]; then
	info "executing: clean"
	while sudo umount $tcldir; do
		true
	done 2>/dev/null
	if sudo losetup -D $devloop; then
		true
	fi 2>/dev/null
	rm -f tcl-8Gb-usb.disk tcl-64Mb-skeleton.disk tcl-64Mb-usb.disk
	rm -rf $tcldir
fi

trap - EXIT
[ "$option" != "" ] && option="$option "
comp "executing: $myname $param ${option}succeded"
echo

