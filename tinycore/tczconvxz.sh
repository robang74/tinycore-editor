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
	local user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

skipvals="0000 2073 1b78 5a58"

trap "umount tmp 2>/dev/null || true" EXIT
set -e
mkdir -p tmp
for i in *.tcz; do
	algo=$(dd if=$i bs=1 skip=$[6*16+13] count=2 2>/dev/null | od -A none -x)
	for id in $skipvals; do
		if [ "$algo" == " $id" ]; then
			continue 2
		fi
	done
	if [ ! -s $i ]; then
		warn "Skipping $i is null"
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
	md5sum $i >$i.md5.txt
done
rmdir tmp
if [ "$SUDO_USER" != "" ]; then
	chownuser *.tcz*
fi
trap -- EXIT

