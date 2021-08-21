#!/bin/bash
#
# Author: Roberto A. Foglietta
#

function realexit() {
	trap - EXIT
	exit $1
}

function atexit() {
	echo
	perr "ERROR: $(basename $0) failed${2+ in $2()} at line $1, abort"
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
	declare user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function download() {
	rc=1
	opt=-c
	if [ "$1" == "-ne" ]; then
		opt=
		rc=0
		shift
		test -e $2 && return 0
	fi
	info "Downloading $2 ..."
	echo
	if which wget >/dev/null; then
		if ! wget --tries=1 $opt $1 -O $2 2>&1; then
			return $rc
		fi
	else
		echo
		perr "ERROR: wget is not available, abort"
		echo
		realexit 1
	fi
}

get_tczlist_full() {
	declare deps i
	for i in $tczlist; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		deps+=" $(tcdepends.sh $i | grep -e "^$i:" | tr -d :)"
	done
	for i in $deps; do echo $i; done | sort | uniq
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

trap 'atexit $LINENO $FUNCNAME' EXIT
set -e

cd $(dirname $0)/..
export PATH="$PATH:$PWD/provides"

if [ "$1" == "clean" ]; then
	rm -f rootfs.gz modules.gz vmlinuz
	rm -f tcz/*.tcz tcz/*.tcz.dep
	rm -f changes/tccustom.tgz
	echo
	comp "COMPLETED: files cleaning in $PWD"
	echo
	realexit 0
fi

if [ -f tinycore.conf ]; then
	cd .
elif [ -f ../tinycore.conf ]; then
	cd ..
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi 
source tinycore.conf
tczlist=$(gettczlist $PWD)
if [ "$tczlist" == "ERROR" ]; then
	realexit 1
fi
cd - >/dev/null

if [ "$1" != "quiet" ]; then
	echo
	warn "Working folder: $PWD"
	warn "Config files: tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"
fi

if which tce-load >/dev/null; then
	if [ ! -x /usr/local/bin/wget ]; then
		su tc -c "tce-load -wi wget"
	fi
else
	if ! which wget >/dev/null; then
		echo
		perr "ERROR: real wget is not available, abort"
		echo
		realexit 1
	fi
fi

download -ne $tcrepo/$distro/rootfs$ARCH.gz rootfs.gz
download -ne $tcrepo/$distro/vmlinuz$ARCH vmlinuz
download -ne $tcrepo/$distro/modules$ARCH.gz modules.gz

if [ "$SUDO_USER" != "" ]; then
	chownuser vmlinuz rootfs.gz modules.gz
fi

deps=$(get_tczlist_full)
mkdir -p tcz
cd tcz
for i in $deps; do
	i=${i/.tcz/}.tcz
	i=${i/KERNEL/$KERN-tinycore$ARCH}
	download -ne $tcrepo/$tczall/$i $i
	download -ne $tcrepo/$tczall/$i.dep $i.dep
	download -ne $tcrepo/$tczall/$i.md5.txt $i.md5.txt
done
cd ..

trap - EXIT
echo
comp "COMLETED: files are ready in $PWD"
echo


