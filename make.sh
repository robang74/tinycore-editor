#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#
  
myip=10.0.2.15
brip=10.0.2.16
tcip=10.0.2.17
netm=24
qemuexec=qemu-system-x86_64 #i386
tcdir="" #if not defined, it will be found
devloop="" #if not defined, it will be found
drvi8GB="format=raw,file=tcl-8GB-usb.disk"
drvboot="format=raw,file=tcl-64MB-usb.disk"
drvdata="id=sd,if=none,bus=1,unit=0,format=raw,file=storage-32GB.disk"
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
image
"

copylist="
tinycore/tcz:
tinycore/flags:
tinycore/tinycore.conf:provides/
tinycore/provides/tc[udp]*.sh:provides/
tinycore/changes/afterboot.sh:
tinycore/changes/{*.sh,*.tgz}:custom/
tinycore/changes/syslinux.cfg:boot/syslinux/
tinycore/changes/boot.msg:boot/syslinux/
crea-usbkey.sh:custom/usbcreate.sh
tinycore/vmlinuz:boot/
tcl-usb-boot-*able.gz:
sshkeys.pub:
"

###############################################################################

function isanipaddr() {
	echo "$1" | grep -qe "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"
}

function usage() {
	echo
	info " USAGE: $myname target"
	echo
	echo -e "\ttargets:"
	echo -e "\t\topen [8GB]"
	echo -e "\t\timage [8GB]"
	echo -e "\t\tqemu-init"
	echo -e "\t\tqemu-test"
	echo -e "\t\tqemu [8GB]"
	echo -e "\t\tssh-copy [8GB] [ip]"
	echo -e "\t\tssh-root [ip]"
	echo -e "\t\tssh-end [8GB]"
	echo -e "\t\tqemu-stop"
	echo -e "\t\tclose [8GB]"
	echo -e "\t\tclean [8GB]"
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
	info "executing: $FUNCNAME"
	declare -i sec=$1
	sleep $sec
	while ! myssh 1 tc "whoami" | grep -qw "tc"; do
		if ! pgrep qemu; then
			return 1
		fi >/dev/null
	done 2>/dev/null
	return 0
}

function tcrootunlock() {
	tcsshdconfig=/usr/local/etc/ssh/sshd_config
	if ls -1 sshkeys.pub/*.pub >/dev/null 2>&1; then
		if myssh 1 root "whoami" | grep -q root; then
			myssh 0 root "unlock.sh"
			return 0
		fi
	fi
	myssh 0 tc "sudo unlock.sh; sudo root-ssh.sh"
	waitforssh
}

function tcdircopy() {
	src=$(echo "$1" | cut -d: -f1)
	dst=$(echo "$1" | cut -d: -f2)
	eval sudo cp -rfL $src $tcldir/$dst && \
		echo -e "\ttransfer $1" | sed "s,:, -> $tcdir/,"
}

function tccopyall() {
	test -n "$tcldir"
	cd tinycore
	./rootfs.sh update
	cd -
	mkdir -p $tcldir/flags
	mkdir -p $tcldir/custom
	mkdir -p $tcldir/provides
	mkdir -p $tcldir/boot/syslinux
	for i in $copylist; do 
		tcdircopy $i
	done
	if [ -e $tcldir/afterboot.sh ]; then
		rm -f $tcldir/custom/afterboot.sh
	fi
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

cd $(dirname $0)
myname="$(basename $0)"

if [ "$USER" != "root" ]; then
	set -m
	if ! timeout 0.2 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	sudo $0 "$@"
	exit $?
fi

param="$1"
shift
option="$1"
shift

syslist="rootfs.gz modules.gz vmlinuz"
trglist="ssh-copy image gpg"

while [ -e tinycore/tinycore.conf ]; do
	for i in $trglist; do
		if [ "$param" == "$i" -o "$param" == "" ]; then
			print=1
			break;
		fi
	done
	test "$print" != "1" && break
	source tinycore/tinycore.conf
	tcrepo=${ARCH:-$tcrepo32}
	tcrepo=${tcrepo/64/$tcrepo64}
	tcsize=${ARCH:-32}
	echo
	warn "Config files: tinycore/tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"
	for i in $syslist; do
		if [ ! -e tinycore/$i ]; then
			echo
			perr "ERROR: file tinycore/$i does not exist"
			echo
	 		warn "SUGGEST: run tinycore/provides/tcgetdistrofiles.sh"
			echo
			exit 1
		fi
	done
	for i in $tczlist; do
		if [ ! -e tinycore/tcz/$i ]; then
			echo
			perr "ERROR: file tinycore/tcz/$i does not exist"
			echo
	 		warn "SUGGEST: run tinycore/provides/tcgetdistrofiles.sh"
			echo
			exit 1
		fi
	done
	break
done

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

if [ "$param" == "ssh-copy" -a "$option" == "8GB" ]; then
	if isanipaddr $1; then
		tcip=$1
		shift
	fi
elif [ "$param" == "ssh-copy" -o  "$param" == "ssh-root" ]; then
	if isanipaddr $option; then
		tcip=$option
		option=""
	fi
fi

if [ "$1" != "" ]; then
	usage; exit 1
fi

if [ "$option" != "8GB" -a "$option" != "" ]; then
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
echo

sshkeycln=yes
warning=""
tdone=0

if [ "$param" == "open" -a "$option" != "8GB" ]; then
	tdone=1
	info "executing: open"
	if [ -e tcl-64MB-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk image"
		exit 1
	fi
	if [ ! -e storage-32GB.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32GB.disk
	fi
	zcat tcl-64MB-usb.disk.gz >tcl-64MB-usb.disk
	chown $SUDO_USER.$SUDO_USER *.disk
	sync
fi

if [ "$param" == "open" -a "$option" == "8GB" ]; then
	tdone=1
	info "executing: open 8GB"
	if [ -e tcl-8GB-usb.disk ]; then
		warning="SUGGEST: run '$myname clean 8GB' to remove existing disk images"
		exit 1
	fi
	if [ ! -e storage-32GB.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32GB.disk
	fi
	zcat tcl-8GB-usb.disk.gz >tcl-8GB-usb.disk
	chown $SUDO_USER.$SUDO_USER *.disk
	sync
fi

if [ "$param" == "image" -a "$option" != "8GB" ]; then
	tdone=1
	info "executing: image"
	if [ -e tcl-64MB-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk images"
		exit 1
	fi
	if [ ! -e storage-32GB.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32GB.disk
	fi
	zcat tcl-64MB-skeleton.disk.gz >tcl-64MB-usb.disk
	sync
	sudo losetup --partscan $devloop tcl-64MB-usb.disk
	if ! sudo fsck -fy ${devloop}p1; then
		sudo fsck -fy ${devloop}p1
	fi
	eval $(grep "^tclabel=" tinycore/changes/rcS)
	dosfslabel ${devloop}p1 $tclabel
	if ! blkid  --label $tclabel $devloop; then
		echo
		warn "WARNING: the label in rcS is '$tclabel' but not in the image"
		rm -f tcl-64MB-usb.disk
		sudo losetup -D $devloop
		exit 1
	fi
	mkdir -p $tcldir
 	if ! sudo mount -o rw ${devloop}p1 $tcldir; then
		rm -f tcl-64MB-usb.disk
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

if [ "$param" == "image" -a "$option" == "8GB" ]; then
	tdone=1
	info "executing: image 8GB"
	if [ ! -e tcl-64MB-usb.disk.gz -a ! -e tcl-64MB-usb.disk ]; then
		$0 image
	else
		echo
		warn "WARNING: using existing 64MB image for 8GB image creation"
		echo
	fi
	if [ ! -e tcl-8GB-usb.disk ]; then
		create=yes
		dd if=/dev/zero bs=1M count=1 seek=7500 of=tcl-8GB-usb.disk
	fi
	if [ -e tcl-64MB-usb.disk ]; then
		dd if=tcl-64MB-usb.disk bs=1M of=tcl-8GB-usb.disk conv=notrunc
	else
		zcat tcl-64MB-usb.disk.gz | dd bs=1M of=tcl-8GB-usb.disk conv=notrunc
	fi
	if [ "$param" == "image" -a "$create" == "yes" ]; then
		losetup --partscan $devloop tcl-8GB-usb.disk
		if true; then
			echo -e "n\n p\n 2\n \n \n N"
			echo -e "t\n 2\n 7\n w"
		fi | fdisk $devloop >/dev/null 2>&1
		mkfs -t ntfs -L NTFS -F -Q ${devloop}p2 >/dev/null
		losetup -D $devloop
	fi
	chown $SUDO_USER.$SUDO_USER tcl-8GB-usb.disk
	sync
fi

stayalive=no
if [ "$param" == "qemu-init" ]; then
	tdone=1
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

if [ "$param" == "qemu-test" ]; then
	tdone=1
	if [ "$option" == "8GB" ]; then
		if [ -e tcl-64MB-usb.disk ]; then
			warn "WARNING: using current tcl-64MB-usb.disk"
		else
			$0 image
		fi
	fi
	$0 image $option && $0 qemu-init && \
		$0 qemu $option
	test "$?" != "0" && realexit 1
	$0 ssh-root
fi

if [ "$param" == "qemu" ]; then
	tdone=1
	info "executing: qemu $option"
	warning="SUGGEST: target open or image to deploy the disk images"
	if [ ! -e storage-32GB.disk ]; then
		exit 1
	elif [ "$option" != "8GB" -a ! -e tcl-64MB-usb.disk ]; then
		exit 1
	elif [ "$option" == "8GB" -a ! -e tcl-8GB-usb.disk ]; then
		exit 1
	fi
	warning=""
	if ! ifconfig brkvm 2>/dev/null | grep -q "inet "; then
		warning="SUGGEST: target qemu-init to uprise the enviroment"
		exit 1
	fi
	if pgrep qemu >/dev/null; then
		warning="SUGGEST: qemu is just running, use it or kill it"
		exit 1
	fi
	if [ "$option" == "8GB" ]; then
		info "executing: qemu will boot from the 8GB image"
		drvboot=$drvi8GB
	fi
	sudo $qemuexec --cpu host --enable-kvm -m 256 -boot c -net nic \
		-net bridge,br=brkvm -drive $drvboot -device sdhci-pci \
		-device sdhci-pci -device sd-card,drive=sd -drive $drvdata &
	info "executing: waiting for the qemu system start-up"
	sshfingerprintclean
	waitforssh 1
fi

if [ "$param" == "ssh-root" ]; then
	tdone=1
	info "executing: ssh $tcip"
	sshfingerprintclean
	killsshafterqemu >/dev/null 2>&1 &
	tcrootunlock
	set +e
	myssh 0 root
	info "executing: ssh-root $tcip completed"
fi

if [ "$param" == "ssh-copy" -a "$option" == "8GB" ]; then
	tdone=1
	info "executing: ssh-copy 8GB $tcip"
	if [ ! -d ntfs ]; then
		warning="SUGGEST: create ntfs folder to copy file in 8GB, abort"
		exit 1
	fi
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	ntdir=${tcdir%1}2
	myscp ntfs/* root@$tcip:$ntdir
fi

if [ "$param" == "ssh-copy" -a "$option" != "8GB" ]; then
	tdone=1
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
	realsync="sync; echo 1 >/proc/sys/kernel/sysrq; echo s >/proc/sysrq-trigger; sync"
	myssh 0 root "test -e $tcdir/tce && tcz2tce.sh >/dev/null; $realsync"
	cd ..
	rm -rf $tcldir
fi

if [ "$param" == "ssh-end" ]; then
	tdone=1
	info "executing: ssh-end $option"
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	if [ "$option" == "8GB" ]; then
		myssh 0 root "ntfs-usbdisk-partition-create.sh && echo DONE" | grep -q DONE
	fi
	myssh 0 root "unlock.sh;
dd if=/dev/zero of=$tcdir/zero; 
sync; rm -f $tcdir/zero; shutdown"
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

if [ "$param" == "qemu-stop" ]; then
	tdone=1
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

if [ "$param" == "close" ]; then
	nclosed=0
	tdone=1
	info "executing: close $option"
	if [ -e tcl-64MB-usb.disk ]; then
		gzip -9c tcl-64MB-usb.disk >tcl-64MB-usb.disk.gz
		let nclosed++ || true
	fi
	if [ "$option" == "8GB" ]; then
		gzip -9c tcl-8GB-usb.disk >tcl-8GB-usb.disk.gz
		let nclosed++ || true
	fi
	chown $SUDO_USER.$SUDO_USER *.disk.gz
	if [[ $nclosed -lt 1 ]]; then
		warning="SUGGEST: do it manually or clean"
		exit 1
	fi
fi

if [ "$param" == "clean" ]; then
	tdone=1
	info "executing: clean $option"
	while sudo umount $tcldir; do
		true
	done 2>/dev/null
	if sudo losetup -D $devloop; then
		true
	fi 2>/dev/null
	rm -f tcl-64MB-skeleton.disk tcl-64MB-usb.disk
	if [ "$option" == "8GB" ]; then
		rm -f tcl-8GB-usb.disk
	fi
	rm -rf $tcldir
fi

trap - EXIT
if [ "$tdone" == "0" ]; then
	usage; exit 1
fi
comp "executing: $myname $param ${option:+$option }succeded"
echo

