#!/bin/bash
#
# Author: Roberto A. Foglietta
#

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

function chownuser() {
	declare user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

trap "umount tmp 2>/dev/null" EXIT
set -e
mkdir -p tmp
for i in *.tcz; do
	algo=$(dd if=$i bs=1 skip=$[6*16+13] count=2 2>/dev/null | od -A none -x)
	if [ "$algo" == " 5a58" -o "$algo" == " 0000" -o "$algo" == " 1b78" ]; then
		continue
	fi
	info "Recompressing $i (algo:$algo)..."
	mount $i tmp
	mksquashfs tmp $i.xz -comp xz -Xbcj x86 >/dev/null
	for k in 1 2 3 4 5; do
		umount tmp 2>/dev/null && break
		sleep 1
	done || umount tmp
	mv -f $i.xz $i
done
rmdir tmp
if [ "$USER" == "root" ]; then
	chownuser *.tcz
fi

