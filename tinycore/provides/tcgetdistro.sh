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
	perr "ERROR: $(basename $0) failed${2+ in $2()} at line $1, abort"
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

function chownuser() {
	local user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function download() {
	local rc=1 opt=-c
	if [ "$1" == "-ne" ]; then
		opt=
		rc=0
		shift
		test -e $2 && return 0
	fi
	info "Downloading $2 ..."
	echo
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

function get_tczlist_full() {
	declare deps i tczdir=$1 getdeps
	getdeps=$tczdir/../provides/tcdepends.sh
	mkdir -p $tczdir
	shift
	for i in $@; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		deps+=" $($getdeps $i | grep -e "^$i:" | cut -d: -f2-)"
		deps+=" $(cat $tczdir/$i.dep 2>/dev/null) $i"
	done
	for i in $deps; do echo $i; done | sort | uniq
}

function tczmetamask() {
	declare i deps="" skipmeta="$2"
	[ -d "$1" ] || return 1
	echo "skipmeta: $skipmeta" >&2
	for i in $tczmeta; do
		[ ! -e "$1/tcz/$i-meta.tcz" ] && continue
		[ "$skipmeta" == "$i" ] && continue
		deps="$deps $(cat $1/conf.d/$i.lst | tr \\n ' ')"
	done
	shift 2
	for i in $@; do
		if echo "$deps" | grep -qe " $i"; then
			echo -e "\tskiptcz: $i" >&2
			continue
		fi
		echo -n " $i"
	done
}

function gettczlist() {
	declare i j tczlist="" deps="" adding
	[ -d "$1" ] || return 1
	for i in $tczmeta; do
		if [ ! -e $1/conf.d/$i.lst ]; then
			echo -e "\n\e[1;31mERROR: tinycore.conf, tczmeta='$i' unsupported\e[0m\n" >&2
			echo "ERROR"
			return 1
		fi
		if [ -e $1/tcz/$i-meta.tcz ]; then
			tczlist="$tczlist $i-meta.tcz"
			continue
		fi
		adding=$(cat $1/conf.d/$i.lst)
		tczlist="$tczlist $(tczmetamask $1 $i $adding)"
	done
	for i in $tczlist; do echo $i; done | sort | uniq
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

trap 'atexit $LINENO $FUNCNAME' EXIT
set -e

cd $(dirname $0)/..
export PATH="$PATH:$PWD/provides"

if [ "$1" == "clean" ]; then
	rm -f rootfs.gz modules.gz vmlinuz
	rm -f tcz/*.tcz tcz/*.tcz.dep
	rm -f changes/tccustom.tgz
	rm -f .arch
	echo
	comp "COMPLETED: files cleaning in $PWD"
	echo
	realexit 0
fi

if [ -f tinycore.conf ]; then
	cd .
elif [ -f ../tinycore.conf ]; then
	cd ..
else
	echo
	perr "ERROR: tinycore.conf is missing, abort"
	echo
	realexit 1
fi 
source tinycore.conf

tczlist=$(gettczlist $PWD)
if [ "$tczlist" == "ERROR" ]; then
	realexit 1
fi
cd - >/dev/null

for i in $tczlist; do
	ok=${i/-meta.tcz/OK}
	ok=${ok: -2}
	if [ "$ok" == "OK" ]; then
		i=${i/-meta.tcz/}
		tczlist="$tczlist $(cat conf.d/$i.lst)"
	fi
done

if [ "$1" != "quiet" ]; then
	echo
	warn "Working folder: $PWD"
	warn "Config files: tinycore.conf"
	warn "Architecture: x86 $tcsize bit"
	warn "Version: $TC.x"
fi

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

if [ ! -e .arch ]; then
	echo $tcsize >.arch
	chownuser .arch
fi
tcsnow=$(cat .arch)
if [ "$tcsnow" != "$tcsize" ]; then
	echo
	perr "ERROR: previous download have been done for x86 $tcsnow bits, abort"
	echo
	warn "SUGGEST: run '$(basename $0) clean' or change ARCH in tinycore.conf"
	echo
	realexit 1
fi

download -ne $tcrepo/$distro/rootfs$ARCH.gz rootfs.gz
download -ne $tcrepo/$distro/vmlinuz$ARCH vmlinuz
download -ne $tcrepo/$distro/modules$ARCH.gz modules.gz

if [ "$SUDO_USER" != "" ]; then
	chownuser vmlinuz rootfs.gz modules.gz .arch
fi

deps=$(get_tczlist_full tcz $tczlist)
mkdir -p tcz
cd tcz
for i in $deps; do
	i=${i/.tcz/}.tcz
	i=${i/KERNEL/$KERN-tinycore$ARCH}
	download -ne $tcrepo/$tczall/$i $i
	download -ne $tcrepo/$tczall/$i.dep $i.dep
	download -ne $tcrepo/$tczall/$i.info $i.info
	download -ne $tcrepo/$tczall/$i.md5.txt $i.md5.txt
done
if [ "$SUDO_USER" != "" ]; then
	chownuser .
fi
cd ..

trap - EXIT
echo
comp "COMLETED: files are ready in $PWD"
echo


