#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function realexit() {
	trap - EXIT
	exit $1
}

function atexit() {
	perr "ERROR: $myname failed at line $1, abort"
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

myname=$(basename $0)

###############################################################################

PS4='DEBUG: $((LASTNO=$LINENO)): '
exec 2> >(grep -ve "^D*EBUG: ")
trap 'atexit $LASTNO' EXIT
set -ex

cd $(dirname $0)/..
WRKDIR="$PWD"

if [ "$1" == "clean" ]; then
	rm -f rootfs.gz modules.gz vmlinuz
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

if [ "$1" != "quiet" ]; then
	echo
	info "Working folder: $WRKDIR"
	info "Config files: tinycore.conf"
	info "Architecture: '$ARCH'"
	info "Version: $TC"
	echo
fi

#if [ ! -e rootfs.gz ]; then
	info "Downloading rootfs.gz..."
	echo
	wget -c $tcrepo/$distro/rootfs.gz 2>&1
#fi

#if [ ! -e vmlinuz ]; then
	info "Downloading vmlinuz..."
	echo
	wget -c $tcrepo/$distro/vmlinuz$ARCH -O vmlinuz 2>&1
#fi

#if [ ! -e modules.gz ]; then
	info "Downloading modules.gz..."
	echo
	wget -c $tcrepo/$distro/modules$ARCH.gz -O modules.gz 2>&1
#fi

if [ "$SUDO_USER" != "" ]; then
	for i in vmlinuz rootfs.gz modules.gz; do
		chown $SUDO_USER.$SUDO_USER $i
	done
fi
mkdir -p tcz
cd tcz
for i in $tczlist; do
#	if [ ! -e $i ]; then
		info "Downloading $i..."
		echo
		wget -c $tcrepo/$tczall/$i 2>&1
#	fi
done
cd ..
if [ "$SUDO_USER" != "" ]; then
	chown -R $SUDO_USER.$SUDO_USER tcz
fi

trap - EXIT
comp "COMLETED: files are ready in $PWD"
echo


