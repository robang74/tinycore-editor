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
	info $opt "[$(cat /proc/uptime | cut -d' ' -f1)] $1"
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

function rotating() {
	while true; do
		printf "%c\b" '\'; sleep $1
		printf "%c\b" '|'; sleep $1
		printf "%c\b" '/'; sleep $1
		printf "%c\b" '-'; sleep $1
	done
}

function tceload() {
	test -z "$1" && return 1
	rotating 0.1 &
	pid=$!
	su tc -c "tce-load -i $*" | \
		grep -v -e "is already installed!" \
			-e "Updating certificates" \
			-e "added.* removed" | \
			tr \\n ' ' | grep .. || \
				echo "no extra tcz!"
	kill $pid
}

depdone=""
function _tceload() {
	mkdir -p /tmp/tcloop
	wd=/usr/local/tce.installed
	for i in $@; do
		test -e $wd/${i/.tcz/} && continue
		if echo "$depdone" | grep -q " $i"; then
			true
		elif grep -q "\.tcz" $tcdir/tcz/$i.dep; then
			depdone="$depdone $i"
			tceload $(cat $tcdir/tcz/$i.dep | tr \\n ' ') $i
			continue
		fi
		load_single_tcz ${i/.tcz/}
	done
	echo
}

function load_single_tcz() {
	rc=KO
	cd /
	while true; do
		mkdir /tmp/tcloop/$1 || break
		mount $tcdir/tcz/$1.tcz /tmp/tcloop/$1 || break
		find /tmp/tcloop/$1 -type d | cut -d/ -f5- | xargs mkdir -p
		eval $(find /tmp/tcloop/$1/ -type f | cut -d/ -f5- | \
			sed -e "s,\(.*\),ln -sf /tmp/tcloop/$1/\1 \1;,")
		eval $(find /tmp/tcloop/$1/ -type l | cut -d/ -f5- | \
			sed -e "s,\(.*\),ln -sf /tmp/tcloop/$1/\1 \1;,")
		wd=/usr/local/tce.installed
		if [ -x $wd/$1 ]; then
			$wd/$1
		else
			touch $wd/$1 2>/dev/null
		fi
		rc=OK
		break
	done
	echo -n "$1 $rc "
	cd - >/dev/null
}

function mount_single_tcz() {
	rc=KO
	while true; do
		mkdir /tmp/tcloop/$1 || break
		mount $tcdev/tcz/$1 /tmp/tcloop/$1 || break
		unionfs -o nonempty /:/tmp/tcloop/$1 / && rc=OK
		wd=/usr/local/tce.installed
		if [ -x $wd/$1 ]; then
			$wd/$1
		else
			touch $wd/$1 2>/dev/null
		fi
	done
	echo $1 $rc

#	unionfs -o nonempty /tmp/tcloop/$1:/ /tmp/alt	# ok
#	unionfs -o nonempty /tmp/tcloop/$1:/ /		# not ok
#	unionfs -o nonempty /:/tmp/tcloop/$1 /		# not ok
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

if [ -d $tcdir/tcz ]; then
	cd $tcdir/tcz
	tczlist=$(ls -1 *.tcz 2>/dev/null)
	calast="ca-certificates.tcz"
	if echo "$tczlist" | grep -q "$calast"; then
		tczlist=$(echo "$tczlist" | grep -v "$calast")
		cacert="$calast"
	fi
	infotime -n "Loading TCZ archives: "
	tceload $tczlist
	tceload $cacert >/dev/null &
	cd - >/dev/null
fi

infotime "Mounting local drives in read only..." ##############################

for i in a b c d; do
	for j in 1 2 3 4; do
		if grep -qe "^/dev/sd$i$j " /proc/mounts; then
			mount -o remount,ro /mnt/sd$i$j
		else
			mkdir -p /mnt/sd$i$j
			mount -r /dev/sd$i$j /mnt/sd$i$j
		fi
	done
done 2>/dev/null

if true; then
	mkdir -p /mnt/sf_Shared
	mount -t vboxsf Shared /mnt/sf_Shared
fi 2>/dev/null

infotime "Customizing the system..." ##########################################

tar xzf $tcdir/custom/tccustom.tgz -moC / >/dev/null 2>&1
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

if [ "$dtdir" == "" ]; then
	infotime "Restoring the data partition..."
	data-usbdisk-partition-create.sh | grep -w data
	dtdir=$(devdir $dtdev)
fi

infotime "Upraising network and VLANs..." #####################################

dhctmo=7
if which dhclient >/dev/null; then
	echo -e "\tusing dhclient..."
	dhclient="timeout $dhctmo dhclient"
	mkdir -p /var/db
else
	echo -e "\tusing udhcpc..."
	dhclient="udhcpc -T1 -t$dhctmo -ni"
fi 2>/dev/null

if ! ifconfig eth0 | grep -q "inet "; then
	echo -ne "\tenabling eth0:"
	ifconfig eth0 up
	if $dhclient eth0 >/dev/null 2>&1; then
		echo " OK"
	else
		echo " KO"
	fi
fi
for k in $tcdir/flags/VLAN-ENA.BLE; do
	if ifconfig eth0 | grep -q "inet "; then
		break;
	fi
	modprobe 8021q
	for i in 1 2; do
		echo -ne "\tenabling eth0.$i:"
		vconfig add eth0 $i
		ifconfig eth0.$i up
		if $dhclient eth0.$i >/dev/null 2>&1; then
			echo " OK"
		else
			echo " KO"
		fi
	done
done

infotime "Upraising SSH for {tc, $tcpassword}..." #############################

for i in /root /home/tc; do
	mkdir -p $i/.ssh
	cat $tcdir/sshkeys.pub/*.pub > $i/.ssh/authorized_keys
	chmod 600 $i/.ssh/authorized_keys
	chmod 700 $i/.ssh $i
done 2>/dev/null
chown -R tc.staff /home/tc

if [ "$tcpassword" != "" ]; then
	echo -ne "\t" >&2
	echo -e "$tcpassword\n$tcpassword" | passwd tc
fi >/dev/null

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
	sshd=1
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
	$(which sshd)
elif which dropbear >/dev/null; then
	sshd=1
	dbdir=/usr/local/etc/dropbear
	if [ "$keygen" == "" ]; then
		echo -ne "\tdropbear converting host keys:"
		dropbearconvert openssh dropbear $dstdir/ssh_host_dsa_key \
			$dbdir/dropbear_dss_host_key && echo -n " dsa"
		dropbearconvert openssh dropbear $dstdir/ssh_host_rsa_key \
			$dbdir/dropbear_rsa_host_key && echo -n " rsa"
		dropbearconvert openssh dropbear $dstdir/ssh_host_ecdsa_key \
			$dbdir/dropbear_ecdsa_host_key && echo -n " ecdsa"
		dropbearconvert openssh dropbear $dstdir/ssh_host_ed25519_key \
			$dbdir/dropbear_ed25519_host_key && echo -n " ed25519"
		echo
	fi
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

###############################################################################

kmap=$(sed -e "s,.* kmap=\([^ ]*\) .*,\1," /proc/cmdline)
if [ -e /usr/share/kmap/$kmap.kmap ]; then
	infotime "Loading keyboard map '$kmap' by kernel ..."
	loadkmap < /usr/share/kmap/$kmap.kmap
else
	infotime "Loading Italian keyboard map..."
	loadkmap < /usr/share/kmap/qwerty/it.kmap
fi 2>/dev/null

infotime "Waiting for background jobs..."
while pgrep tce-load; do sleep 0.2; done >/dev/null 2>&1

