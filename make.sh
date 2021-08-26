#!/bin/bash
#
# Author: Roberto A. Foglietta
#

cd $(dirname $0)

if [ -e make.conf ]; then
	source make.conf
fi

tcdir="" #if not defined, it will be found
devloop="" #if not defined, it will be found
drvi8GB="format=raw,file=tcl-8GB-usb.disk"
drvboot="format=raw,file=tcl-usb.disk"
drvdata="id=sd,if=none,bus=1,unit=0,format=raw,file=storage-32GB.disk"
tcldir="tcldisk"

targets="
open
qemu-init
qemu-test
qemu
ssh-root
ssh-copy
ssh-end
ssh
qemu-stop
close
clean
distclean
image
download
busybox
iso
"

copylist="
tinycore/flags:
tinycore/tinycore.conf:provides/
tinycore/provides/tc[udpm]*.sh:provides/
tinycore/provides/tc*deps.db.gz:provides/
tinycore/changes/afterboot.sh:
tinycore/changes/{*.sh,*.tgz}:custom/
tinycore/changes/syslinux.cfg:boot/syslinux/
tinycore/changes/boot.msg:boot/syslinux/
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
	info "USAGE: $myname target"
	echo
	echo -e "\t targets:"
	echo -e "\t\t open [8GB]"
	echo -e "\t\t image [8GB]"
	echo -e "\t\t qemu-init"
	echo -e "\t\t qemu-test [8GB|iso]"
	echo -e "\t\t qemu [8GB|iso]"
	echo -e "\t\t ssh-copy [8GB] [\$ipaddr]"
	echo -e "\t\t ssh-root [\$ipaddr]"
	echo -e "\t\t ssh-end [8GB]"
	echo -e "\t\t ssh [\$ipaddr]"
	echo -e "\t\t qemu-stop"
	echo -e "\t\t close [8GB]"
	echo -e "\t\t clean [8GB|all]"
	echo -e "\t\t distclean"
	echo -e "\t\t download"
	echo -e "\t\t busybox"
	echo -e "\t\t iso"
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
	if [ "$1" == "" ]; then
		if which luit >/dev/null; then
			luit="luit -encoding ISO-8859-1"
		fi
	fi
	if [ "$SUDO_USER" == "" ]; then
		runasuser="bash -c "
		timeout=""
	else
		runasuser="su -m $SUDO_USER -c"
		timeout="timeout $tout"
	fi
	tout=${tout/1000d/10}
	$runasuser "exec -a myssh $timeout $luit sshpass -p $pass ssh -o StrictHostKeyChecking=no -o ConnectTimeout=$tout $user@$tcip \"$@\""
	if [ "$luit" != "" ]; then
		reset 2>&1 | sed -e "s,$(printf '\33c'),," >&2
		echo
	fi
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
	info "make.sh executing: $FUNCNAME"
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

function get_tczlist_full() {
	declare deps i tczdir=$1 getdeps
	getdeps=$tczdir/../provides/tcdepends.sh
	shift
	for i in $@; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		deps+=" $($getdeps $i | grep -e "^$i:" | cut -d: -f2-)"
		deps+=" $(cat $tczdir/$i.dep 2>/dev/null) $i"
	done
	for i in $deps; do echo $i; done | sort | uniq
}

function tczmetamask() {
	declare i deps="" skipmeta="$2"
	[ -d "$1" ] || return 1
	echo "skipmeta: $skipmeta" >&2
	for i in $tczmeta; do
		[ ! -e "$1/tcz/$i-meta.tcz" ] && continue
		[ "$skipmeta" == "$i" ] && continue
		deps="$deps $(cat $1/conf.d/$i.lst | tr \\n ' ')"
	done
	shift 2
	for i in $@; do
		if echo "$deps" | grep -qe " $i"; then
			echo -e "\tskiptcz: $i" >&2
			continue
		fi
		echo -n " $i"
	done
}

function gettczlist() {
	declare i j tczlist="" deps="" adding
	[ -d "$1" ] || return 1
	for i in $tczmeta; do
		if [ ! -e $1/conf.d/$i.lst ]; then
			echo -e "\n\e[1;31mERROR: tinycore.conf, tczmeta='$i' unsupported\e[0m\n" >&2
			echo "ERROR"
			return 1
		fi
		if [ -e $1/tcz/$i-meta.tcz ]; then
			tczlist="$tczlist $i-meta.tcz"
			continue
		fi
		adding=$(cat $1/conf.d/$i.lst)
		tczlist="$tczlist $(tczmetamask $1 $i $adding)"
	done
	for i in $tczlist; do echo $i; done | sort | uniq
}

function tccopyall() {
	test -n "$tcldir"
	cd tinycore
	./tccustom.sh
	ln -sf ../tccustom$tcsize.tgz changes/tccustom.tgz
	chownuser tccustom*.tgz changes
	if [ -e ../busybox/src/busybox ]; then
		../busybox/busybox.sh update quiet
	else
		./rootfs.sh update
	fi
	cd - >/dev/null
	mkdir -p $tcldir/flags
	mkdir -p $tcldir/custom
	mkdir -p $tcldir/provides
	mkdir -p $tcldir/boot/syslinux
	for i in $copylist; do 
		tcdircopy $i
	done
	if [ -e $tcldir/afterboot.sh ]; then
		chmod a+x $tcldir/afterboot.sh
		rm -f $tcldir/custom/afterboot.sh
	fi
	chmod a+x $tcldir/custom/*.sh
	cat tinycore/{rootfs.gz,modules.gz} > $tcldir/boot/core.gz && \
		echo -e "\ttransfer tinycore/{rootfs.gz,modules.gz} -> /$tcldir/boot/core.gz"
	if [ -e busybox/.patches_applied -o -e busybox/.patches_applied.close ]; then
		cp -rf busybox/patches $tcldir && \
			echo -e "\ttransfer busybox/patches -> /$tcldir/"
	fi
	if [ "$1" == "" ]; then
		tczdir=$tcldir/tce/optional
		mkdir -p $tcldir/tce
		echo "$tczlist" >$tcldir/tce/onboot.lst
	elif [ "$1" == "iso" ]; then
		tczdir=$tcldir/cde/optional
		mkdir -p $tcldir/cde
		echo "$tczlist" >$tcldir/cde/onboot.lst
	else
		tczdir=$tcldir/tcz
	fi
	mkdir -p $tczdir/upgrade $tczdir/../ondemand
	tczlistfull=$(get_tczlist_full tinycore/tcz $tczlist)
	for i in $tczlistfull; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if [ ! -e tinycore/tcz/$i.md5.txt ]; then
			cd tinycore/tcz
			md5sum $i >$i.md5.txt
			chownuser $i.md5.txt
			cd - >/dev/null
		fi
		if [ -s tinycore/tcz/$i ]; then
			touch tinycore/tcz/$i.info
			chownuser tinycore/tcz/$i.info
			cp -f tinycore/tcz/{$i,$i.dep,$i.info,$i.md5.txt} $tczdir
		fi
	done
	echo -e "\ttransfer tinycore/tcz/{selected *.tcz} -> /$tczdir/"
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
			if [ "$SUDO_USER" == "" ]; then
				yes "" | ssh-keygen
			else
				yes "" | su -l $SUDO_USER -c "ssh-keygen"
			fi
		fi 2>/dev/null
		if [ -e ~/.ssh/known_hosts ]; then
			if [ "$SUDO_USER" == "" ]; then
				ssh-keygen -R $tcip
			else
				su -l $SUDO_USER -c "ssh-keygen -R $tcip"
			fi
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

function storage_32GB_create()
{
	if [ ! -e storage-32GB.disk ]; then
		dd if=/dev/zero bs=512 count=1 seek=61071359 of=storage-32GB.disk
		chownuser storage-32GB.disk
	fi
}

function chownuser() {
	declare user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function isatarget() {
	declare i
	for i in $targets; do
		if [ "$1" == "$i" ]; then
			return 0
		fi
	done
	return 1
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

myname="$(basename $0)"

if [ "$1" != "--real" ]; then
	if isatarget $1; then
		options="$1"
		shift 
		while ! isatarget $1; do
			test "$1" == "" && break
			options+=" $1"
			shift
		done
		if [ "$1" == "iso" ]; then
			if echo "$options" | grep -q qemu; then
				options+=" $1"
				shift
			fi
		fi
		$0 --real $options || realexit $?
		rc=$?
		test "$1" == "" && realexit $rc
		$0 $@
		realexit $?
	else
		usage
		realexit 1
	fi
else
	shift
fi

param="$1"
shift
option="$1"
shift

rootlist="qemu-init qemu-test qemu qemu-stop image iso"

for i in $rootlist; do
	if [ "$param" == "$i" -o "$param" == "" ]; then
		broot=1
		break;
	fi
done

if [ "$broot" == "1" ]; then
	if [ "$USER" != "root" ]; then
		set -m
		if ! timeout 0.2 sudo -n true; then
			echo
			warn "WARNING: $myname requires root permissions"
			echo
		fi 2>/dev/null
		sudo $0 "$param $option $*"
		exit $?
	fi
fi

syslist="rootfs.gz modules.gz vmlinuz"
trglist="ssh-copy image iso"

while true; do
	for i in $trglist; do
		if [ "$param" == "$i" -o "$param" == "" ]; then
			print=1
			break;
		fi
	done
	test "$print" != "1" && break

	cd tinycore
	if [ ! -r tinycore.conf ]; then
		echo
		perr "ERROR: tinycore/tinycore.conf is not readable, abort"
		echo
		realexit 1
	fi
	source tinycore.conf
	echo
	warn "Config files: tinycore/tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"

	if [ ! -e .arch ]; then
		echo $tcsize >.arch
		chownuser .arch
	fi
	tcsnow=$(cat .arch)
	if [ "$tcsnow" != "$tcsize" ]; then
		echo
		perr "ERROR: previous download have been done for x86 $tcsnow bits, abort"
		echo
		warn "SUGGEST: run '$myname distclean' or change ARCH in tinycore.conf"
		echo
		realexit 1
	fi

	for i in $tczmeta; do
		test -e tcz/$i.list || continue
		if [ conf.d/$i.lst -nt tcz/$i.list ]; then
			echo
			perr "WARNING: conf.d/$i.lst is newer than tcz/$i.list"
			echo
			echo "If you did changes then delete and rebuild the meta packages"
			echo "otherwise touch tinycore/tcz/$i.list to ignore this message"
			echo
			exit 1
		fi
	done

	tczlist=$(gettczlist $PWD)
	if [ "$tczlist" == "ERROR" ]; then
		exit 1
	fi
	cd - >/dev/null

	for i in $syslist; do
		if [ ! -e tinycore/$i ]; then
			echo
			perr "ERROR: file tinycore/$i does not exist"
			echo
			warn "SUGGEST: run tinycore/provides/tcgetdistro.sh"
			echo
			exit 1
		fi
	done
	cd tinycore/tcz
	for i in $tczlist; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if [ ! -e $i ]; then
			echo
			perr "ERROR: file tinycore/tcz/$i does not exist"
			echo
			warn "SUGGEST: run tinycore/provides/tcgetdistro.sh"
			echo
			exit 1
		fi
		for j in $(cat $i.dep); do
			j=${j/.tcz/}.tcz
			j=${j/KERNEL/$KERN-tinycore$ARCH}
			if ! ls $j >/dev/null 2>&1; then
				echo
				perr "ERROR: $i missing $j in tcz, abort"
				echo
				exit 1
			fi
		done
	done
	#
	# XZ compression waste RAM and it is acceptable for x86_64 architecture
	#
	if [ "$ARCH" == "64" -a -x ../tczconvxz.sh ]; then
		../tczconvxz.sh
	fi
	cd - >/dev/null
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
elif [ "$param" == "ssh-copy" -o "$param" == "ssh-root" -o "$param" == "ssh" ]; then
	if isanipaddr $option; then
		tcip=$option
		option=""
	fi
fi

if [ "$1" != "" ]; then
	usage; exit 1
fi

if [ "$param" == "clean" -a "$option" == "all" ]; then
	true
elif [ "$param" == "qemu" -a "$option" == "iso" ]; then
	true
elif [ "$param" == "qemu-test" -a "$option" == "iso" ]; then
	true
elif [ "$option" != "8GB" -a "$option" != "" ]; then
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

if [ "$ifnm" != "" ]; then
	if ! ifconfig $ifnm >/dev/null; then
		echo
		perr "ERROR: selected network interface is not correct"
		echo
		warn "SUGGEST: change 'ifnm' in make.conf or set to void"
		warn "         if you are not going to use qemu/network"
		echo
	fi
fi

myip=$(ifconfig $ifnm | sed -ne "s,.*inet \([^ ]*\) .*,\\1,p")
myip=${myip:-xxx}

###############################################################################

trap 'atexit' EXIT
set -e
echo

eval $(grep "^tclabel=" tinycore/changes/rcS)
sshkeycln=yes
warning=""
tdone=0

if [ "$param" == "download" ]; then
	tdone=1
	info "make.sh executing: download"
	tinycore/provides/tcgetdistro.sh
	busybox/busybox.sh download
fi

if [ "$param" == "busybox" ]; then
	tdone=1
	info "make.sh executing: busybox"
	busybox/busybox.sh all
fi

if [ "$param" == "open" -a "$option" != "8GB" ]; then
	tdone=1
	info "make.sh executing: open"
	if [ -e tcl-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk image"
		exit 1
	fi
	storage_32GB_create
	zcat tcl-usb.disk.gz >tcl-usb.disk
	chownuser tcl-usb.disk
	sync
fi

if [ "$param" == "open" -a "$option" == "8GB" ]; then
	tdone=1
	info "make.sh executing: open 8GB"
	if [ -e tcl-8GB-usb.disk ]; then
		warning="SUGGEST: run '$myname clean 8GB' to remove existing disk images"
		exit 1
	fi
	storage_32GB_create
	zcat tcl-8GB-usb.disk.gz >tcl-8GB-usb.disk
	chownuser tcl-8GB-usb.disk
	sync
fi

if [ "$param" == "iso" ]; then
	tdone=1
	info "make.sh executing: iso"
	rm -rf $tcldir
	mkdir -p $tcldir
	tar xzf tcl-boot-isolinux.tgz -C $tcldir
	tccopyall iso
	cp -arf DATA $tcldir/data
	echo -e "\ttransfer DATA -> /$tcldir/data"
	mkisofs -l -Jr -V "$tclabel" -no-emul-boot -boot-load-size 4 -boot-info-table \
		-b boot/syslinux/isolinux.bin -c boot/syslinux/boot.cat -o tclinux.iso $tcldir
	chownuser tclinux.iso
	rm -rf $tcldir
	echo
fi

if [ "$param" == "image" -a "$option" != "8GB" ]; then
	tdone=1
	info "make.sh executing: image"
	if [ -e tcl-usb.disk ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk images"
		exit 1
	fi
	storage_32GB_create
	zcat tcl-skeleton.disk.gz >tcl-usb.disk
	sync
	sudo losetup --partscan $devloop tcl-usb.disk
	if ! sudo fsck -fy ${devloop}p1; then
		sudo fsck -fy ${devloop}p1
	fi
	dosfslabel ${devloop}p1 $tclabel
	if ! blkid  --label $tclabel $devloop; then
		echo
		warn "WARNING: the label in rcS is '$tclabel' but not in the image"
		rm -f tcl-usb.disk
		sudo losetup -D $devloop
		exit 1
	fi
	rm -rf $tcldir
	mkdir -p $tcldir
 	if ! sudo mount -o rw ${devloop}p1 $tcldir; then
		rm -f tcl-usb.disk
		sudo losetup -D $devloop
		rmdir $tcldir
		exit 1
	fi
	tccopyall
	sudo dd if=/dev/zero of=$tcldir/zero >/dev/null 2>&1 || true
	sync; sudo rm -f $tcldir/zero $tcldir/FSCK????.REC; sync
	du -ks $tcldir
	k=0; sleep 1
	while ! sudo umount $tcldir; do
		[[ $k -lt 5 ]]
		k=$[k+1]
		sleep 1
	done 2>/dev/null
	sudo losetup -D $devloop
	chownuser *.disk
	rmdir $tcldir
	echo
	sync
fi

if [ "$param" == "image" -a "$option" == "8GB" ]; then
	tdone=1
	info "make.sh executing: image 8GB"
	if [ ! -e tcl-usb.disk.gz -a ! -e tcl-usb.disk ]; then
		$0 image
	else
		echo
		warn "WARNING: using existing USB image for 8GB image creation"
		echo
	fi
	if [ ! -e tcl-8GB-usb.disk ]; then
		create=yes
		dd if=/dev/zero bs=1M count=1 seek=7500 of=tcl-8GB-usb.disk
	fi
	if [ -e tcl-usb.disk ]; then
		dd if=tcl-usb.disk bs=1M of=tcl-8GB-usb.disk conv=notrunc
	else
		zcat tcl-usb.disk.gz | dd bs=1M of=tcl-8GB-usb.disk conv=notrunc
	fi
	if [ "$param" == "image" -a "$create" == "yes" ]; then
		losetup --partscan $devloop tcl-8GB-usb.disk
		echo -e "n\n p\n 2\n \n \n N\n w" | fdisk $devloop >/dev/null 2>&1
		if echo "$tczmeta" | grep -wq "develop"; then
			mkfs -t ext4 -L DATA -F ${devloop}p2 >/dev/null
		else
			echo -e "t\n 2\n 7\n w" | fdisk $devloop >/dev/null 2>&1
			mkfs -t ntfs -L DATA -F -Q ${devloop}p2 >/dev/null
		fi
		losetup -D $devloop
	fi
	chownuser tcl-8GB-usb.disk
	echo
	sync
fi

stayalive=no
if [ "$param" == "qemu-init" ]; then
	tdone=1
	info "make.sh executing: qemu-init"
	if ! ifconfig $ifnm | grep -qe "inet .*$myip"; then
		echo
		perr "ERROR: network configuration is wrong, abort"
		echo
		warn "SUGGEST: change 'ifnm' parameter in make.conf"
		echo
		realexit 1
	fi 2>/dev/null
	if ! ifconfig brkvm 2>/dev/null | grep -q "inet "; then
		brctl addbr brkvm
		ip addr add $brip/$netm dev brkvm
		ip link set brkvm up
		mkdir -p /etc/qemu
		mkdir -p /var/lib/misc
		touch /etc/qemu/bridge.conf
		echo "allow brkvm" | sudo tee /etc/qemu/bridge.conf
		sudo dnsmasq --interface=brkvm --bind-interfaces --dhcp-range=$tcip,$tcip
		if ! iptables -nvL FORWARD | grep -qe " ACCEPT .* all .* brkvm *$ifnm"; then
			iptables -A FORWARD -i brkvm -o $ifnm -j ACCEPT
		fi
		if ! iptables -t nat -nvL POSTROUTING | grep -qe " MASQUERADE *all .* \* *$ifnm "; then
			iptables -t nat -A POSTROUTING -o $ifnm -j MASQUERADE
		fi
		sysctl -w net.ipv4.ip_forward=1
		sshfingerprintclean
	else
		stayalive=yes
	fi
fi

if [ "$param" == "qemu-test" ]; then
	tdone=1
	if [ "$option" == "8GB" ]; then
		if [ -e tcl-usb.disk ]; then
			warn "WARNING: using current tcl-usb.disk"
		else
			$0 image
		fi
	fi
	action=${option:-image}
	action=${option/8GB/image 8GB}
	$0 $action && $0 qemu-init && \
		$0 qemu $option
	test "$?" != "0" && realexit 1
	$0 ssh-root
fi

if [ "$param" == "qemu" ]; then
	tdone=1
	info "make.sh executing: qemu $option"
	warning="SUGGEST: target open or image to deploy the disk images"
	if [ "$option" == "iso" ]; then
		test -e tclinux.iso || $0 iso
	elif [ "$option" == "8GB" -a ! -e tcl-8GB-usb.disk ]; then
		exit 1
	elif [ "$option" != "8GB" -a ! -e tcl-usb.disk ]; then
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
		info "make.sh executing: qemu will boot from the 8GB image"
		drvboot=$drvi8GB
	fi
	storage_32GB_create
	if [ "$option" == "iso" ]; then
		sudo $qemuexec $qemuopts -m $qemumem -boot d -net nic \
			-net bridge,br=brkvm -cdrom tclinux.iso -device sdhci-pci \
			-device sdhci-pci -device sd-card,drive=sd -drive $drvdata &
	else
		sudo $qemuexec $qemuopts -m $qemumem -boot c -net nic \
			-net bridge,br=brkvm -drive $drvboot -device sdhci-pci \
			-device sdhci-pci -device sd-card,drive=sd -drive $drvdata &
	fi
	info "make.sh executing: waiting for the qemu system start-up"
	sshfingerprintclean
	waitforssh 1
fi

if [ "$param" == "ssh-root" ]; then
	tdone=1
	info "make.sh executing: ssh-root $tcip"
	sshfingerprintclean
	killsshafterqemu >/dev/null 2>&1 &
	tcrootunlock
	set +e
	myssh 0 root
	info "make.sh executing: ssh-root $tcip completed"
fi

if [ "$param" == "ssh" ]; then
	tdone=1
	info "make.sh executing: ssh $tcip"
	sshfingerprintclean
	killsshafterqemu >/dev/null 2>&1 &
	set +e
	myssh 0 tc
	info "make.sh executing: ssh $tcip completed"
fi

if [ "$param" == "ssh-copy" -a "$option" == "8GB" ]; then
	tdone=1
	info "make.sh executing: ssh-copy 8GB $tcip"
	if [ ! -d DATA ]; then
		warning="SUGGEST: create data folder to copy file in 8GB, abort"
		exit 1
	fi
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	ntdir=${tcdir%1}2
	echo -e "\ttransfering everything to $tcip:$ntdir..."
	myscp DATA/* root@$tcip:$ntdir && \
		echo -e "\ttransfered everything to $tcip:$ntdir -- OK"
	echo -e "\tWait for syncing the remote drive..."
	myssh 0 root sync
	echo
fi

if [ "$param" == "ssh-copy" -a "$option" != "8GB" ]; then
	tdone=1
	info "make.sh executing: ssh-copy $tcip"
	if [ -e "$tcldir" ]; then
		warning="SUGGEST: run '$myname clean' to remove existing disk folder"
		exit 1
	fi
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	tccopyall
	cd $tcldir
	chownuser .
	echo -e "\ttransfering everything to $tcip:$tcdir..."
	myscp * root@$tcip:$tcdir && \
		echo -e "\ttransfered everything to $tcip:$tcdir -- OK"
	echo -e "\tWait for syncing the remote drive..."
	myssh 0 root sync
	echo
	cd ..
	rm -rf $tcldir
fi

if [ "$param" == "ssh-end" ]; then
	tdone=1
	info "make.sh executing: ssh-end $option"
	sshfingerprintclean
	tcrootunlock
	sshgettcdir
	if [ "$option" == "8GB" ]; then
		myssh 0 root "data-usbdisk-partition-create.sh && echo DONE" | grep -q DONE
	fi
	myssh 0 root "unlock.sh;
mount -o remount,async $tcdir;
dd if=/dev/zero of=$tcdir/zero;
sync; rm -f $tcdir/zero; 
/sbin/poweroff"
	info "make.sh executing: waiting for the qemu system shut down"
	k=0
	sleep 1
	while myssh 1 tc "whoami" 2>&1 | grep -wq "tc"; do
		pgrep qemu >/dev/null || break
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
	info "make.sh executing: qemu-stop"
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
	info "make.sh executing: close $option"
	if [ -e tcl-usb.disk ]; then
		gzip -9c tcl-usb.disk >tcl-usb.disk.gz
		rm -f tcl-usb.disk
		let nclosed++ || true
	fi
	if [ "$option" == "8GB" ]; then
		gzip -9c tcl-8GB-usb.disk >tcl-8GB-usb.disk.gz
		rm -f tcl-8GB-usb.disk
		let nclosed++ || true
	fi
	chownuser *.disk.gz
	if [[ $nclosed -lt 1 ]]; then
		warning="SUGGEST: do it manually or clean"
		exit 1
	fi
fi

if [ "$param" == "clean" ]; then
	tdone=1
	info "make.sh executing: clean $option"
	while sudo umount $tcldir; do
		true
	done 2>/dev/null
	if sudo losetup -D $devloop; then
		true
	fi 2>/dev/null
	rm -f tcl-skeleton.disk tcl-usb.disk
	if [ "$option" == "8GB" ]; then
		rm -f tcl-8GB-usb.disk
	elif [ "$option" == "all" ]; then
		rm -f tcl-8GB-usb.disk storage-32GB.disk
	fi
	rm -rf $tcldir tclinux.iso
fi

if [ "$param" == "distclean" ]; then
	tdone=1
	info "make.sh executing: distclean"
	tinycore/provides/tcgetdistro.sh clean
	busybox/busybox.sh distclean
	rm -rf tinycore/tcz/*
	$0 clean all
fi

if [ "$param" == "iso" -o "$param" == "image" ]; then
	if [ ! -x busybox/src/rootfs/bin/busybox ]; then
		warn "SUGGEST: run ./make.sh busybox redo $param"
		echo
	fi
fi

trap - EXIT
if [ "$tdone" == "0" ]; then
	usage; exit 1
fi
comp "executing: $myname $param ${option:+$option }succeded"
echo

