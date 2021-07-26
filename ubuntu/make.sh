#!/bin/bash
#
# Author: Roberto A. Foglietta
#

set -ex

if [ "$1" == "rootfs" ]; then

	repo=https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release
	distro=ubuntu-base-20.04.2-base-amd64.tar.gz
	nointr="debconf debconf/frontend select Noninteractive"
	user=$(whoami)

	wget -c $repo/$distro
	mkdir rootfs
	sudo tar xzf $distro -C rootfs
	  
	sudo mount -t proc proc rootfs/proc
	sudo mount --rbind /sys rootfs/sys
	sudo mount --rbind /dev rootfs/dev

	sudo cp debnames.txt make.sh rootfs
	sudo chroot rootfs /make.sh chroot

	cd rootfs
	sudo umount ./proc/
	sudo mount --make-rslave sys
	sudo umount -R ./sys/
	sudo mount --make-rslave dev
	sudo umount -R ./dev/
	sudo tar xzf ../grub-config.tgz
	sudo tar czf ../system.tgz .
	cd ..

	sudo chown $USER.$USER system.tgz

elif [ "$1" == "chroot" ]; then

	echo -e "root\nroot\n" | passwd
	echo "nameserver 8.8.8.8" >/etc/resolv.conf
	apt update
	echo "
	ATTENTION:

		when asked on which disk grub should automatically installed
		select none pressing ENTER then answer yes to grub installation

		press ENTER to continue
	"
	read
	export DEBIAN_FRONTEND=noninteractive
	echo "$nointr" | debconf-set-selections
	apt install -y $(cat debnames.txt)
#	rm -f /etc/resolv.conf

	mkdir -p /boot/grub/fonts
	cp -rf /usr/lib/grub/i386-pc /boot/grub
	cp -rf /usr/share/grub/unicode.pf2 /boot/grub/fonts

#	cd /boot/grub
#	cp -arf grub.cfg grub.cfg.old
#	srt=$(grep -ne "BEGIN .*/30_os-prober" grub.cfg | cut -d: -f1)
#	end=$(grep -ne "END .*/30_os-prober" grub.cfg | cut -d: -f1)
#	len=$(cat grub.cfg | wc -l)
#	head -n$srt grub.cfg > grub.cfg.1
#	tail -n$[len-end+1] grub.cfg > grub.cfg.2
#	cat grub.cfg.1 grub.cfg.2 >grub.cfg
#	rm -f grub.cfg.1 grub.cfg.2
#	cd -
	 
	exit

else
	echo
	echo "USAGE: $(basename $0) rootfs|chroot"
	echo
fi
