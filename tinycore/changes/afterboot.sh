#!/bin/ash
#
# Author: Roberto A. Foglietta
#

function info() {
	if [ "$1" == "-n" ]; then
		shift
		echo -ne "\e[1;36m$@\e[0m"
	else
		echo -e "\e[1;36m$@\e[0m"
	fi
}

function infotime() {
	opt=""
	if [ "$1" == "-n" ]; then
		opt="$1"
		shift
	fi
	tm="$(printf '%5.2f' $(cat /proc/uptime | cut -d' ' -f1))"
	info $opt "[$tm] $1"
}

function warntime() {
	opt=""
	if [ "$1" == "-n" ]; then
		opt="$1"
		shift
	fi
	warn $opt "[$(cat /proc/uptime | cut -d' ' -f1)] $1"
}

function warn() {
	echo -e "\e[1;33m$@\e[0m"
}

function devdir() {
	sed -ne "s,^$1 \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

function tceload() {
	opt="-i"
	if [ "$1" == "-bg" ]; then
		opt="-bi"
		shift
	fi
	test -z "$1" && return 1
	user=$(cat /etc/sysconfig/tcuser)
	user=${user:-tc}
	su $user -c "tce-load $opt $*" | \
		grep -v -e "is already installed!" \
			-e "Updating certificates" \
			-e "added.* removed" | \
			tr \\n ' ' | grep .. || \
				echo "no extra tcz!" &
	rotdash $!
	if [ "$opt" == "-bi" ]; then
		one=${1/.tcz/}
		if [ -x /usr/local/tce.installed/$one ]; then
			/usr/local/tce.installed/$one
			touch /run/$one.done
		fi >/dev/null 2>&1 &
	fi	
}

function waitcacerts() {
	for i in $(pgrep ca-certificates); do
		rotdash $i
	done
	touch /run/ca-certificates.done
}

###############################################################################

tcpassword="tinycore"
copylist="
unlock.sh:unlock.sh
reboot.sh:reboot.sh
tcz2tce.sh:tcz2tce.sh
shutdown.sh:shutdown.sh
root-ssh.sh:root-ssh.sh
tcldevdir.sh:tcldevdir.sh
resetbysf.sh:resetbysf.sh
usbsetboot.sh:usbsetboot.sh
dev2chroot.sh:dev2chroot.sh
sysinstall.sh:system-install.sh
datacrea.sh:data-usbdisk-partition-create.sh
"

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

set +e

libcrypt=$(realpath /lib/libcrypt.so.1)
if echo $libcrypt | grep -q "libcrypt.so.1"; then
	warntime "Real libcrypt: $libcrypt (inherited)"
else
	infotime "Real libcrypt: $libcrypt (native)"
fi

infotime "Lookup for tinycore partitions..." ##################################

devel=$(cat /etc/sysconfig/devel)
tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
dtdev=$(readlink /etc/sysconfig/dtdev)
dtdir=$(readlink /etc/sysconfig/dtdir)
dtdir=${dtdir:-$(devdir $dtdev)}
devel=${devel:+ext4}
type=${devel:-ntfs}

if [ "$tcdev" == "" ]; then
	echo
	warn "WARNING: I cannot find TinyCore device, abort!"
	echo
	exit 1
fi

if [ "$tcdir" == "" ]; then
	tcdir=${tcdev/dev/mnt}
	mkdir -p $tcdir
	mount -o ro $tcdev $tcdir || exit 1
fi

if [ "$dtdir" == "" ]; then
	dtdir=${dtdev/dev/mnt}
	mkdir -p $dtdir
	mount -t $type -o ro $dtdev $dtdir || dtdir=""
fi 2>/dev/null

infotime "Mounting local drives in read only..." ##############################

disks=$(grep -e "sd[a-d][0-4]$" /proc/partitions | tr -s ' ' | cut -d' ' -f5)
for i in $disks; do
#	warntime "remounting $i"
	if grep -qe "^/dev/$i " /proc/mounts; then
		mount -o remount,ro /mnt/$i
	else
		mkdir -p /mnt/$i
		mount -r /dev/$i /mnt/$i
	fi
done 2>/dev/null &
lastpid=$!

if true; then
	mkdir -p /mnt/sf_Shared
	mount -t vboxsf Shared /mnt/sf_Shared
fi 2>/dev/null

infotime "Customizing the system..." ##########################################

tar xzf $tcdir/custom/tccustom.tgz -moC /
ldconfig

. /etc/os-release
echo "$PRETTY_NAME" >/etc/issue

gpg=$(which gpg2)
gpg=${gpg%2}
test -n "$gpg" && ln -sf gpg2 "$gpg"
if ! which shutdown >/dev/null; then
	echo "poweroff" >/sbin/shutdown
	chmod a+x /sbin/shutdown
fi
if [ ! -e /bin/broot ]; then
	echo "cd; sudo su -l root" >/bin/broot
	chmod a+x /bin/broot
fi
touch /etc/sysconfig/superuser
cat /home/tc/.ashrc >/root/.ashrc
cat /home/tc/.profile >>/root/.profile

for i in $copylist; do
	src=$(echo "$i" | cut -d: -f1)
	dst=$(echo "$i" | cut -d: -f2)
	if ls $tcdir/custom/$src; then
		cp -arf $tcdir/custom/$src /bin/$dst
		chmod a+x /bin/$dst
	fi >/dev/null
done
chown -R tc.staff /home/tc

###############################################################################

if [ -d $tcdir/tcz ]; then
	cd $tcdir/tcz
	metalist=$(ls -1 *-meta.tcz 2>/dev/null)
	tczlist=$(ls -1 *.tcz 2>/dev/null | grep -ve "-meta.tcz$")
	calast="ca-certificates.tcz"
	if echo "$tczlist" | grep -q "$calast"; then
		tczlist=$(echo "$tczlist" | grep -v "$calast")
		cacert="$calast"
	fi
	infotime -n "Loading TCZ archives: "
	tceload $metalist | tr \\n \\0
	tceload $tczlist || echo
	tceload -bg $cacert
	cd - >/dev/null
	ldconfig
if false; then
	infotime -n "Installing TCZ archives: "
	if true; then
		cd /usr/local/tce.installed
		list=$(ls -1t | grep -v "ca-certificates")
		for i in $list; do
			test -x $i || continue; ./$i
			echo $? >/run/$i.rc
		done
		if [ -x ./ca-certificates ]; then
			./ca-certificates &
		fi
	fi >/dev/null &
	rotdash $!
	echo "OK"
fi
fi

###############################################################################

if [ "$dtdir" == "" ]; then
	infotime "Restoring the data partition..."
	rotdash $lastpid >/dev/null
	data-usbdisk-partition-create.sh |\
		sed -ne "s,\(.* data .*\),\t\1,p"
	dtdir=$(devdir $dtdev)
fi

infotime "Creating the crypto keys..." ########################################

find=/etc/ssh/sshd_config.orig
found=$(ls -1d $find /usr/local/$find 2>/dev/null | head -n1)
found=${found:-$find}
sshdconfig=${found%%.orig}
dstdir=$(dirname $sshdconfig)
mkdir -p $dstdir
if ! tar xzf $tcdir/custom/sshdhostkeys.tgz -moC $dstdir; then
	keygen="-R"
fi 2>/dev/null

if which sshd >/dev/null; then
	if [ "$keygen" != "" ]; then
		ssh-keygen -A
		ssh-keygen -m PEM -p -N '' -f $dstdir/ssh_host_dsa_key
		ssh-keygen -m PEM -p -N '' -f $dstdir/ssh_host_rsa_key
		ssh-keygen -m PEM -p -N '' -f $dstdir/ssh_host_ecdsa_key
		ssh-keygen -m PEM -p -N '' -f $dstdir/ssh_host_ed25519_key
	fi
	if cat $sshdconfig.orig >$sshdconfig; then
		authstr=PubkeyAuthentication
		sed -ie "s,.*$authstr.*,$authstr yes," $sshdconfig
		if ! grep -qe "$authstr" $sshdconfig; then
			echo "$authstr yes" >>$sshdconfig
		fi
	fi
elif which dropbear >/dev/null; then
	dbdir=/usr/local/etc/dropbear
	if [ "$keygen" == "" ]; then
		dropbearconvert openssh dropbear $dstdir/ssh_host_dsa_key \
			$dbdir/dropbear_dss_host_key
		dropbearconvert openssh dropbear $dstdir/ssh_host_rsa_key \
			$dbdir/dropbear_rsa_host_key
		dropbearconvert openssh dropbear $dstdir/ssh_host_ecdsa_key \
			$dbdir/dropbear_ecdsa_host_key
		dropbearconvert openssh dropbear $dstdir/ssh_host_ed25519_key \
			$dbdir/dropbear_ed25519_host_key
	fi
fi 2>/dev/null &
pid=$!

infotime "Upraising network and VLANs..." #####################################

dhctmo=10
if which dhclient >/dev/null; then
	netmsg="\tusing dhclient..."
	dhclient="timeout $dhctmo dhclient"
	mkdir -p /var/db
else
	netmsg="\tusing udhcpc..."
	dhclient="udhcpc -T1 -t$dhctmo -ni"
fi

if [ -e $tcdir/flags/ETH0-STATIC.UP ]; then
	echo -e "\tusing static settings..."
	source $tcdir/flags/ETH0-STATIC.UP
	nodhcp=1
else
	ifconfig eth0 up
fi

if grep -qw nodhcp /proc/cmdline; then
	echo -e "\tcommand line nodhcp"
	nodhcp=1
fi
if [ "$nodhcp" == "1" ]; then
	echo -ne "\tstatic eth0  : "
	if ifconfig eth0 | grep -q "inet "; then
		netset=1
		echo "OK"
	else
		echo "KO"
	fi
else
	netset=1
	echo -e "$netmsg"
	echo -ne "\tenabling eth0: "
	if ifconfig eth0 | grep -q "inet "; then
		echo "OK"
	elif $dhclient eth0 >/dev/null 2>&1; then
		echo "OK"
	else
		echo "KO"
	fi &
	rotdash $!
fi
while [ "$nodhcp" != "1" ]; do
	test -e $tcdir/flags/VLAN-ENA.BLE || break
	if ifconfig eth0 | grep -q "inet "; then
		break;
	fi
	netset=1
	modprobe 8021q
	for i in 1 2; do
		echo -ne "\tenabling eth0.$i: "
		vconfig add eth0 $i
		ifconfig eth0.$i up
		if $dhclient eth0.$i >/dev/null; then
			echo "OK"
		else
			echo "KO"
		fi &
		rotdash $!
	done 2>/dev/null
	break
done

if [ "$netset" != "1" ]; then
	echo -e "\tno settings found."
else infotime "Upraising SSH for {tc, $tcpassword}..." ########################

for i in /root /home/tc; do
	mkdir -p $i/.ssh
	cat $tcdir/sshkeys.pub/*.pub > $i/.ssh/authorized_keys
	chmod 600 $i/.ssh/authorized_keys
	chmod 700 $i/.ssh $i
done 2>/dev/null
chown -R tc.staff /home/tc

echo -ne "\twaiting for the crypto keys: "
rotdash $pid
echo "OK"

if [ "$tcpassword" != "" ]; then
	echo -ne "\t" >&2
	echo -e "$tcpassword\n$tcpassword" | passwd tc
fi >/dev/null

if which sshd >/dev/null; then
	sshd=1
	$(which sshd)
elif which dropbear >/dev/null; then
	sshd=1
	dropbear $keygen
fi 2>/dev/null

if [ "$sshd" == "1" ]; then
	echo
	warn "\t>>> SSH user: tc, password: $tcpassword <<<"
	echo
else
	echo
	warn "\tNo SSH server found, service not available"
	echo
fi

fi ############################################################################

kmap=$(sed -e "s,.* kmap=\([^ ]*\) .*,\1," /proc/cmdline)
if [ -e /usr/share/kmap/$kmap.kmap ]; then
	infotime "Loading keyboard map '$kmap' by kernel ..."
	loadkmap < /usr/share/kmap/$kmap.kmap
else
	infotime "Loading Italian keyboard map..."
	loadkmap < /usr/share/kmap/qwerty/it.kmap
fi 2>/dev/null

infotime "Waiting for background jobs..."
if [ -x /usr/local/tce.installed/ca-certificates ]; then
	echo -ne "\tca-certificates: "
	if grep -qw nowait /proc/cmdline; then
		echo "nowait"
	else
		waitcacerts
		echo "OK"
	fi
fi
echo -ne "\tremounting-ro: "
rotdash $lastpid; echo "OK"

