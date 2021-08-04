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


if [ "$1" == "" -o "$2" != "" ]; then
	echo
	warn "USAGE: $(basename $0) \"string\""
	echo
	exit 1
fi

mypath=$(dirname $0)
if [ -f $mypath/tinycore.conf ]; then
	source $mypath/tinycore.conf
elif [ -f $mypath/../tinycore.conf ]; then
	source $mypath/../tinycore.conf
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	exit 1
fi

tcrepo=${ARCH:-$tcrepo32}
tcrepo=${tcrepo/64/$tcrepo64}

cd $mypath

if [ ! -e tc${TC}.db.gz ]; then
	echo
	perr "ERROR: tc${TC}.db.gz does not exist, use tcupdatedb.sh"
	echo
	exit 1
fi

search=$(echo "$1" | tr ' ' '~')
found=$(zcat tc${TC}.db.gz | tr ' ' '~' | grep -e "$search")
echo
for i in $found; do
	info "$(echo $i | cut -d: -f1)"
	echo "$i" | tr \; \\n | grep -e "$search";
	echo
done

