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

set -e
trap 'atexit' EXIT
mypath=$(dirname $0)
if [ -f $mypath/tinycore.conf ]; then
	source $mypath/tinycore.conf
elif [ -f $mypath/../tinycore.conf ]; then
	source $mypath/../tinycore.conf
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi

tcrepo=${ARCH:-$tcrepo32}
tcrepo=${tcrepo/64/$tcrepo64}

cd $mypath

echo
info "Updating tc$TC.db.gz ..."
if [ -e tc$TC.db.gz ]; then
	echo
	warn "WARNING: database tc$TC.db.gz exists"
	echo
	echo -n "Do you want to delete it [N/y]? "
	while read ans; do
		if [ "$ans" == "Y" -o "$ans" == "y" ]; then
			rm -f tc$TC.db.gz
			break
		elif [ "$ans" == "N" -o "$ans" == "n" ]; then
			realexit 1
		fi	
	done
fi

wget -c $tcrepo/$tczall/provides.db
awk -v VER=":TC$TC" 'BEGIN {FS="\n";OFS=";";RS=""} {$1=$1 VER; print}' provides.db > tc$TC.db
rm -f provides.db
gzip -9f tc$TC.db
comp "Update tc$TC.db.gz successfully completed"
echo
realexit 0

