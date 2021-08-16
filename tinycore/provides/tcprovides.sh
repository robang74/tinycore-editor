#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

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

if [ "$1" == "" -o "$2" != "" ]; then
	echo
	warn "USAGE: $(basename $0) \"string\""
	echo
	exit 1
fi

cd $(dirname $0)

if [ -f tinycore.conf ]; then
	source tinycore.conf
elif [ -f ../tinycore.conf ]; then
	source ../tinycore.conf
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	exit 1
fi

datafile=tc$TC-$tcsize.db
search=$(echo "$1" | tr ' ' '~')
found=$(zcat $datafile.gz | tr ' ' '~' | grep -e "$search")

if [ ! -e $datafile.gz ]; then
	echo
	perr "ERROR: $datafile.gz does not exist, use tcupdatedb.sh"
	echo
	exit 1
fi

echo
warn "Working folder: $PWD"
warn "Config files: tinycore.conf"
warn "Architecture: x86 $tcsize bit"
warn "Version: $TC.x"
echo

for i in $found; do
	info "$(echo $i | cut -d: -f1)"
	echo "$i" | tr \; \\n | grep -e "$search";
	echo
done

