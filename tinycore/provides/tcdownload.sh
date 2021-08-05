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

###############################################################################

if [ "$1" == "" ]; then
	echo
	warn "USAGE: $(basename $0) name.tgz"
	echo
	exit 1
fi

set -e
trap 'atexit' EXIT
i="tinycore.conf"
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

echo
for i in "$@"; do
	info "Downloading $i ..."
	if ! echo $i | grep -qe "\.tcz$"; then
		i="$i.tcz"
	fi
	wget -c $tcrepo/$tczall/$i
done
comp "$(basename $0) completed successfully"
echo
realexit 0

