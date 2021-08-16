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
	if which curl >/dev/null; then
		opt=${opt:--f}
		opt=${opt/-c/-C -}
		if ! curl --retry 0 $opt $1 -o $2 2>&1; then
			echo -n >$2
			return $rc
		fi
	elif which wget >/dev/null; then
		if ! wget --tries=1 $opt $1 -O $2 2>&1; then
			return $rc
		fi
	else
		echo
		perr "ERROR: no curl nor wget is installed, abort"
		echo
		realexit 1
	fi
}

###############################################################################

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
	cd ..
	source tinycore.conf
	cd - >/dev/null
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi

cd - >/dev/null

tcrepo=${ARCH:-$tcrepo32}
tcrepo=${tcrepo/64/$tcrepo64}
tcsize=${ARCH:-32}

echo
warn "Working folder: $PWD"
warn "Config files: tinycore.conf"
warn "Architecture: x86 $tcsize bit"
warn "Version: $TC.x"
echo

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
	info "Downloading $i ..."
	if ! echo $i | grep -qe "\.tcz$"; then
		i="$i.tcz"
	fi
	download $tcrepo/$tczall/$i $i
	i="$i.dep"
	download -ne $tcrepo/$tczall/$i $i
done
comp "$(basename $0) completed successfully"
echo
realexit 0

