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
	case "$1" in
	-ne) opt=""; rc=0; shift
		;;
	-neb) opt="-b"; rc=0; shift
		;;
	*) return 1
		;;
	esac
	if which wget >/dev/null; then
		if ! wget -nv --tries=1 $opt $1 -O $2 2>&1; then
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

dbfile="tc$TC-$tcsize-deps.db"

info "Updating $dbfile.gz ..."
if [ -e $dbfile.gz ]; then
	echo
	warn "WARNING: database $dbfile.gz exists"
	echo
	echo -n "Do you want to overwrite it [N/y]? "
	while read ans; do
		if [ "$ans" == "Y" -o "$ans" == "y" ]; then
			break
		else
			echo abort
			echo
			realexit 1
		fi	
	done
fi

if [ "$1" != "--tmp" ]; then
	rm -rf tmp
	mkdir -p tmp
	cd tmp

	download -ne $tcrepo/$tczall index.lst
	max=$(cat index.lst | wc -l)

	printf "concurrent wgets:               "
	for i in $(cat index.lst); do
		download -neb $tcrepo/$tczall/$i.dep $i.dep >/dev/null
		n=$(pgrep -x wget | wc -l)
		m=$(ls -1 *.dep | wc -l)
		printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b" 
		printf "%2d %4d / %4d" $n $m $max
		rm -f wget-log*
		while [[ $n -ge 8 ]]; do 
			sleep 0.1
			n=$(pgrep -x wget | wc -l)
		done
	done
	while [[ $n -gt 0 ]]; do
		printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b" 
		printf "%2d %4d / %4d" $n $m $max
		rm -f wget-log*
		sleep 0.1
		n=$(pgrep -x wget | wc -l)
		m=$(ls -1 *.dep | wc -l)
	done
	echo
else
	cd tmp
fi

function getmissing() {
	grep "No such file" missing.lst | cut -d: -f2 | sort | uniq
}

for tcz in $(cat index.lst); do
	tcz=${tcz/KERNEL/$KERN-tinycore$ARCH}
	info "Checking $tcz ..."
	deps=$(cat $tcz.dep || true)
	deps=$(echo "$deps" | sort)
	ndps=$deps
	n=1
	m=$(getmissing | wc -l)
	printf "\tmissing: %d, cycles: 0" $m
	while [ "$deps" != "" ]; do
		printf " $n"
		for i in $deps; do
			i=${i/.tcz/}.tcz
			i=${i/KERNEL/$KERN-tinycore$ARCH}
			ndps="$ndps
$(cat $i.dep 2>missing.lst || true)"
		done
		ndps=$(echo "$ndps" | sort | uniq)
		[ "$deps" == "$ndps" ] && break
		deps=$ndps
		let n++
	done
	echo "$tcz:"$ndps >> ../$dbfile
	echo
done

missing64="man-db.tcz boost-1.65-python.tcz icu61-dev.tcz Clipit.tcz gnu-efi-dev.tcz python3.6-olefile.tcz enchant-dev.tcz gtksourceview-dev.tcz ijs.tcz libgnome-keyring.tcz gegl-gir.tcz boost.tcz Xdialog.tcz libstartup-notification.tcz graphics-5.4.3-tinycore64.tcz py3.6cups.tcz libvirt-python3.6.tcz"

missing32="libgnome-keyring.tcz evas-dev.tcz evas.tcz udev-lib-dev.tcz python3.6-olefile.tcz libuninameslist.tcz googletest.tcz libplist.tcz confuse.tcz confuse-dev.tcz audiofile.tcz node-dev.tcz wxwidgetsgtk3.tcz rest.tcz Xdialog.tcz twolame.tcz"

if false; then
	cd ..
	if [ "$tcsize" == "32" ]; then
		for i in $missing32; do
			sed -i "s, $i,,g" $dbfile
		done
	elif [ "$tcsize" == "64" ]; then
		for i in $missing64; do
			sed -i "s, $i,,g" $dbfile
		done
	fi
else
	missing=$(getmissing)
	if [ "$missing" == "" ]; then
		for i in $missing; do
			sed -i "s, $i,,g" ../$dbfile
		done
		echo
		warn "MISSING:"$missing
		echo
	fi
	cd ..
fi
gzip -9f $dbfile

if [ "$1" != "--tmp" ]; then
	rm -rf tmp
fi

echo
comp "$(basename $0) completed successfully"
echo
realexit 0

