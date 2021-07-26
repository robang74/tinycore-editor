#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
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

function warn() {
	echo -e "\e[1;33m$@\e[0m"
}

function devdir() {
	sed -ne "s,$1 \([^ ]*\) .*,\1,p" /proc/mounts | head -n1
}

###############################################################################

tcpassword="tinycore"
label="TINYCORE"
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
usbcreate.sh:bootable-usbdisk-create.sh
ntfscrea.sh:ntfs-usbdisk-partition-create.sh
"

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

set +e

infotime "Lookup for $label partitions..." ###################################

tcdev=$(blkid | grep -e "=.$label. " | cut -d: -f1)
tcdir=$(mount | grep -e "$tcdev on" | cut -d' ' -f3)
ntdev=$(echo $tcdev | sed -e "s,1$,2,")
ntdir=$(mount | grep -e "$ntdev on" | cut -d' ' -f3)

if [ "$tcdir" == "" ]; then
	tcdir=$(echo "$tcdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $tcdir
	mount -o ro $tcdev $tcdir
fi

if [ "$ntdir" == "" ]; then
	ntdir=$(echo "$ntdev" | sed -e "s,/dev/,/mnt/,")
	mkdir -p $ntdir
	mount -o ro -t ntfs $ntdev $ntdir || ntdir=""
	
fi

if [ -d $tcdir/tcz ]; then
	infotime -n "Loading TCZ archives: "
	su - tc -c "tce-load -i $tcdir/tcz/*.tcz" | tr \\n ' '
	echo
fi

infotime "Mounting local drives in read only..." ##############################

for i in a b c d; do
	for j in 1 2; do
		if mount | grep -q "/dev/sd$i$j on"; then
			mount -o remount,ro /mnt/sd$i$j
		else
			mkdir -p /mnt/sd$i$j
			mount -o ro /dev/sd$i$j /mnt/sd$i$j
		fi
	done
done 2>/dev/null

if true; then
	mkdir -p /mnt/sf_Shared
	mount -t vboxsf Shared /mnt/sf_Shared
fi 2>/dev/null

infotime "Customizing the system..." ##########################################

tar xzf $tcdir/custom/tccustom.tgz -moC / >/dev/null 2>&1

. /etc/os-release
echo "$PRETTY_NAME" >/etc/issue

if [ ! -x /bin/bash ]; then
	echo "ash \"\$@\"" >/bin/bash
	chmod a+x /bin/bash
fi
gpg=$(which gpg2 | sed -e "s,2$,,")
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
		cp -arf $tcdir/custom/$src /sbin/$dst 
		chmod a+x /sbin/$dst
	fi >/dev/null
done
chown -R tc.staff /home/tc

if [ "$ntdir" == "" ]; then
	infotime "Restoring the NTFS partition..."
	ntfs-usbdisk-partition-create.sh | grep -w ntfs
fi

infotime "Upraising network and VLANs..." #####################################

if which dhclient >/dev/null; then
	echo -e "\tusing dhclient..."
	dhclient="timeout 5 dhclient"
	mkdir -p /var/db
else
	echo -e "\tusing udhcpc..."
	dhclient="udhcpc -T1 -t5 -ni"
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

function getsshconfigfile() {
	find=/etc/ssh/sshd_config
	ls -1d $find /usr/local/$find 2>/dev/null | head -n1
}

if ! tar xzf $tcdir/custom/sshdconfig.tgz -moC /; then
	sshdconfig=$(getsshconfigfile)
	cat $sshdconfig.orig >$sshdconfig
	ssh-keygen -A
fi 2>/dev/null

for i in /root /home/tc; do
	mkdir -p $i/.ssh
	cat $tcdir/sshkeys.pub/* > $i/.ssh/authorized_keys
	chmod 600 $i/.ssh/authorized_keys
	chmod 700 $i/.ssh $i
done
chown -R tc.staff /home/tc

sshdconfig=$(getsshconfigfile)
authstr=PubkeyAuthentication
sed -ie "s,.*$authstr.*,$authstr yes," $sshdconfig
if ! grep -qe "$authstr" $sshdconfig; then
	echo "$authstr yes" >>$sshdconfig
fi

if [ "$tcpassword" != "" ]; then
	echo -e "$tcpassword\n$tcpassword" | passwd tc
fi >/dev/null
nohup $(which sshd) >/dev/null 2>&1 &
echo
warn ">>> SSH user: tc, password: $tcpassword <<<"
echo

###############################################################################

kmap=$(sed -e "s,.* kmap=\([^ ]*\) .*,\1," /proc/cmdline)
if [ -e /usr/share/kmap/$kmap.kmap ]; then
	infotime "Loading keyboard map '$kmap' by kernel ..."
	loadkmap < /usr/share/kmap/$kmap.kmap
else
	infotime "Loading Italian keyboard map..."
	loadkmap < /usr/share/kmap/qwerty/it.kmap
fi 2>/dev/null

