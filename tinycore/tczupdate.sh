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
	perr "ERROR: $(basename $0) at line $1 failed"
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
	local rc=1 opt=-c
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

trap 'atexit $LINENO' EXIT
set -e

myname=$(basename $0)
cd $(dirname $0)
WRKDIR="$PWD"

if [ ! -e tinycore.conf ]; then
	cp -f tinycore.conf.orig tinycore.conf
	chownuser tinycore.conf
fi
source tinycore.conf

cd tcz
updated=""
for i in $(ls -1 *.tcz); do
	if echo $i | grep -qe "-meta.tcz"; then
		continue
	fi
# RAF: the tcz could have been compressed with xz and md5sum changed
#	download -ne $tcrepo/$tczall/$i.md5.txt $i.md5
#	if ! diff $i.md5.txt $i.md5 >/dev/null; then
#		rm -f $i*
#		../provides/tcdownload.sh $i
#	fi
#	rm -f $i.md5
	download -ne $tcrepo/$tczall/$i.info $i.updt
	if ! diff $i.info $i.updt >/dev/null; then
		rm -f $i*
		../provides/tcdownload.sh $i
		updated="${updated:+$updated }$i"
	fi
	rm -f $i.updt
done

if [ "$updated" ]; then
	for i in $tczmeta; do
		[ -e $i-meta.tcz ] && remeta="yes"
		rm -f $i*
	done
	cd ..
	./tczmetamerge.sh
	echo
	warn "Some tcz has been updated, meta packages rebuilt"
	echo "$updated"
	echo
else
	echo
	comp "No any tcz has been updated"
	echo
fi

realexit 0

