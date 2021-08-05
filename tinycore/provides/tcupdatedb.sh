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
	perr "ERROR: $(basename $0) failed, abort"
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

tcrepo=${ARCH:-$tcrepo32}
tcrepo=${tcrepo/64/$tcrepo64}
tcsize=${ARCH:-32}
datafile=tc$TC-$tcsize.db

if [ "$1" != "quiet" ]; then
	echo
	warn "Working folder: $PWD"
	warn "Config files: tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"
fi

echo
info "Updating $datafile.gz ..."
if [ -e $datafile.gz ]; then
	echo
	warn "WARNING: database $datafile.gz exists"
	echo
	echo -n "Do you want to delete it [N/y]? "
	while read ans; do
		if [ "$ans" == "Y" -o "$ans" == "y" ]; then
			rm -f $datafile.gz
			break
		else
			echo abort
			echo
			realexit 1
		fi	
	done
fi

wget -c $tcrepo/$tczall/provides.db
awk -v VER=":TC$TC" 'BEGIN {FS="\n";OFS=";";RS=""} {$1=$1 VER; print}' provides.db > $datafile
rm -f provides.db
gzip -9f $datafile
comp "Update $datafile.gz successfully completed"
echo
realexit 0

