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
	perr "ERROR: $(basename $0) of '$i' failed"
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

function download() {
	rc=1
	opt=-c
	if [ "$1" == "-ne" ]; then
		opt=
		rc=0
		shift
	fi
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

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$1" == "" ]; then
	echo
	warn "USAGE: $(basename $0) [-d \$dirname] name.tgz"
	echo
	exit 1
fi

set -e
trap 'atexit' EXIT

cd $(dirname $0)

if [ -f tinycore.conf ]; then
	source tinycore.conf
elif [ -f ../tinycore.conf ]; then
	source ../tinycore.conf
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi

cd - >/dev/null

echo
warn "Working folder: $PWD"
warn "Config files: tinycore.conf"
warn "Architecture: x86 $tcsize bit"
warn "Version: $TC.x"
echo

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

for i in "$@"; do
	if [ "$setdir" == "1" ]; then
		cd $i || usage
		setdir=0
		continue
	fi
	if [ "$i" == "-d" ]; then
		setdir=1
		continue
	fi
	i=${i/.tcz/}.tcz
	i=${i/KERNEL/$KERN-tinycore$ARCH}
	info "Downloading $i ..."
	download $tcrepo/$tczall/$i $i
	download -ne $tcrepo/$tczall/$i.dep $i.dep
	download -ne $tcrepo/$tczall/$i.info $i.info
	download -ne $tcrepo/$tczall/$i.md5.txt $i.md5.txt
done
comp "$(basename $0) completed successfully"
echo
realexit 0

