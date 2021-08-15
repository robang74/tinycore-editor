#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function realexit() {
	trap - EXIT
	exit $1
}

function atexit() {
	echo
	perr "ERROR: $(basename $0) failed at line $1, abort"
	echo
	realexit 1
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

function chownuser() {
	guid=$(grep -e "^$SUDO_USER:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function download() {
	if which curl >/dev/null; then
		curl -C - $1 -o $2
	elif which wget >/dev/null; then
		wget -c $1 -O $2
	else
		echo
		perr "ERROR: no curl nor wget is installed, abort"
		echo
		realexit 1
	fi
}

###############################################################################

PS4='DEBUG: $((LASTNO=$LINENO)): '
exec 2> >(grep -ve "^D*EBUG: ")
trap 'atexit $LASTNO' EXIT
set -ex

cd $(dirname $0)/..

if [ "$1" == "clean" ]; then
	rm -f rootfs.gz modules.gz vmlinuz
	rm -f changes/tccustom.tgz
	rm -f tcz/*.tcz
	echo
	comp "COMPLETED: files cleaning in $PWD"
	echo
	realexit 0
fi

if [ -f tinycore.conf ]; then
	source tinycore.conf
elif [ -f ../tinycore.conf ]; then
	source ../tinycore.conf
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi 2>/dev/null

tcrepo=${ARCH:-$tcrepo32}
tcrepo=${tcrepo/64/$tcrepo64}
tcsize=${ARCH:-32}

if [ "$1" != "quiet" ]; then
	echo
	warn "Working folder: $PWD"
	warn "Config files: tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"
fi

if which tce-load >/dev/null; then
	su - tc -c "tce-load -wi wget"
fi

#if [ ! -e rootfs.gz ]; then
	info "Downloading rootfs.gz..."
	echo
	download $tcrepo/$distro/rootfs$ARCH.gz rootfs.gz 2>&1
#fi

#if [ ! -e vmlinuz ]; then
	info "Downloading vmlinuz..."
	echo
	download $tcrepo/$distro/vmlinuz$ARCH vmlinuz 2>&1
#fi

#if [ ! -e modules.gz ]; then
	info "Downloading modules.gz..."
	echo
	download $tcrepo/$distro/modules$ARCH.gz modules.gz 2>&1
#fi

if [ "$SUDO_USER" != "" ]; then
	chownuser vmlinuz rootfs.gz modules.gz
fi
mkdir -p tcz
cd tcz
for i in $tczlist; do
#	if [ ! -e $i ]; then
		info "Downloading $i..."
		echo
		download $tcrepo/$tczall/$i $i 2>&1
#	fi
done
cd ..
if [ "$SUDO_USER" != "" ]; then
	chownuser tcz
fi

trap - EXIT
comp "COMLETED: files are ready in $PWD"
echo


