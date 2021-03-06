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

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$1" == "" ]; then
	echo
	warn "USAGE: $(basename $0) name.tgz"
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

echo
warn "Working folder: $PWD"
warn "Config files: tinycore.conf"
warn "Architecture: x86 $tcsize bit"
warn "Version: $TC.x"
echo

dbfile="tc$TC-$tcsize-deps.db.gz"

if [ ! -e $dbfile ]; then
	echo
	perr "ERROR: $dbfile does not exist, use tcupdatedb.sh"
	echo
	realexit 1
fi

for i in $@; do
	info "Checking $i ..."
	if ! echo $i | grep -qe "\.tcz$"; then
		i="$i.tcz"
	fi
	if ! zcat $dbfile | grep -e "^$i:"; then
		echo
		perr "ERROR: $i is not present in database, abort"
		echo
		realexit 1
	fi
done
echo
comp "$(basename $0) completed successfully"
echo
realexit 0

