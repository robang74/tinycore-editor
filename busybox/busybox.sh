#!/bin/bash
#
# Author: Roberto A. Foglietta
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

function usage() {
	info "USAGE: $myname \$target"
	echo
	echo -e "\t targets:"
	echo -e "\t\t download         (retrieve source)"
	echo -e "\t\t checklib         (check GLIBC version)"
	echo -e "\t\t open             (deploy source)"
	echo -e "\t\t compile          (from scratch)"
	echo -e "\t\t install          (into rootfs.gz)"
	echo -e "\t\t editconfig       (change config)"
	echo -e "\t\t saveconfig       (save config)"
	echo -e "\t\t update           (quick compile & install)"
	echo -e "\t\t close            (save the source)"
	echo -e "\t\t all              (open, compile & install)"
	echo -e "\t\t clean            (delete the source)"
	echo -e "\t\t distclean        (delete everything)"
	echo
	realexit 1
}

function checkfordir() {
	if [ ! -d "$1" ]; then
		echo
		perr "ERROR: src folder does not exist, run $myname $2"
		echo
		realexit 1
	fi
}

function checkconfig() {
	case $1 in
	suid|nosuid)
		;;
	default)
		echo
		perr "ERROR: src/.config.type value is unknown"
		echo
		realexit 1
	esac
}

function setconfig() {
	checkconfig $1
	echo $1 > .config.type
	cat ../config.$1 >.config
	if [ -e ../config.$1.patch -a ! -e ../.patches_applied.close ]; then
		patch -Np1 -i ../config.$1.patch
	fi
}

function chownuser() {
	local user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function usermake() {
	local nproc
	nproc=$(nproc 2>/dev/null || true)
	nproc=${nproc:-2}
#	nproc=1 #RAF: sometimes the compilation fails with -j > 1
	if [ "$SUDO_USER" != "" ]; then
		su $SUDO_USER bash -c "make -j$nproc $1"
	else
		make -j$nproc $1
	fi
}

function realexit() {
	trap - EXIT
	exit $1
}

function download() {
	local rc=1 opt=-c
	if [ "$1" == "-ne" ]; then
		opt=
		rc=0
		shift
		test -e "$2" && return
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

function onerror() {
	local rc=$?
	echo
	perr "ERROR: $myname failed${2+ in $2()} at line $1, rc: $rc"
	echo
	realexit $rc
}

###############################################################################

if [ "$USER" != "root" -a "$1" != "" ]; then
	set -m
	if ! timeout 0.2 sudo -n true; then
		echo
		warn "WARNING: $myname requires root permissions"
		echo
	fi 2>/dev/null
	sudo $0 "$@"
	exit $?
fi

mydir=$(dirname $0)
myname=$(basename $0)

cd $mydir
mydir=$PWD

tcdir=$(realpath ../tinycore)
cd $tcdir
if [ -f tinycore.conf ]; then
	source tinycore.conf
else
	source tinycore.conf.orig
fi
cd - >/dev/null
if [ -f busybox.sh.conf ]; then
	source busybox.sh.conf
else
	source busybox.sh.conf.orig
fi

if echo "$source" | grep -qe "\.git$"; then
	version="latest-git"
fi

arch=${ARCH:--m32}
arch=${arch/64/-m64}
archtune=${arch/-m64/$cputune64}
archtune=${archtune/-m32/$cputune32}
export CFLAGS="$arch $archtune $ccopts"
export LDFLAGS="$arch"
compile="CFLAGS='$CFLAGS' LDFLAGS='$LDFLAGS'"
bb_bin_pkg="busybox-rootfs-${arch/-m/}.tar.bz2"

###############################################################################

trap 'onerror $LINENO $FUNCNAME' ERR
set -Ee

if [ "${1/dist/}" == "clean" ]; then
	set -- $1 quiet
fi

if [ "$2" != "quiet" ]; then
	echo
	warn "Working folder is $PWD"
	warn "Architecture: x86 ${arch/-m/} bit"
	warn "Version: $version"
	echo

	if [ ! -e ../tinycore/.arch ]; then
		echo $tcsize >../tinycore/.arch
		chownuser .arch
	fi
	tcsnow=$(cat ../tinycore/.arch)
	tcsnow=${tcsnow:-32}
	if [ "$tcsnow" != "$tcsize" ]; then
		echo
		perr "ERROR: previous download have been done for x86 $tcsnow bits, abort"
		echo
		warn "SUGGEST: run '$myname distclean' or change ARCH in tinycore.conf"
		echo
		realexit 1
	fi
else
	echo
	exec &> >(grep -v "./_install")
fi

if [ "$1" == "download" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing download..."
	if which tce-load >/dev/null; then
		tczlist="wget patch make linux-${KERN::-3}_api_headers"
		tczlist+=" gcc glibc_base-dev libtirpc-dev"
		tczlist+=" glibc_add_lib advcomp squashfs-tools"
		su - tc -c "tce-load -wi $tczlist"
	fi | grep -ve "already installed" | tr \\n ' '
	echo
	download -ne $confsuid config.suid
	download -ne $confnosuid config.nosuid

	if echo "$source" | grep -qe "\.git$"; then
		if (cd src 2>/dev/null; git pull); then
			mv src busybox-$version
		else
			git clone $source
			mv busybox busybox-$version
		fi
		chownuser busybox-$version
		tar cjf busybox.tar.bz2 busybox-$version
		chownuser busybox.tar.bz2
		mv busybox-$version src
	else
		download -ne $source busybox.tar.bz2
	fi
	mkdir -p patches
	for i in $patchlist; do
		download -ne $tcbbsrc/$i patches/$i
	done
	chownuser patches *suid *.bz2
fi

if [ "$1" == "all" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing all..."
	$0 open
	$0 compile
	$0 install
fi

if [ "$1" == "checklib" ]; then
	done=1
	info "busybox.sh executing checklib..."
	hver=$(ldd --version | head -n1)
	hnver=${hver//.}
	hnver=${hnver: -3}
	$tcdir/rootfs.sh open >/dev/null
	libc=$tcdir/rootfs.tmp/lib/libc.so.6
	gver=$(strings $libc | grep "GNU C Library")
	gnver=${gver//./}
	gnver=${gnver: -3}
	$tcdir/rootfs.sh clean >/dev/null
	harch=$(uname -m)
	harch=${harch/i?86/32}
	harch=${harch/x86_64/64}
	garch=${ARCH:-32}
	echo
	warn "glibc host : $hver ($harch bit)"
	warn "glibc guest: $gver ($garch bit)"
	if [[ $harch -eq $garch && $gnver -ge $hnver ]]; then
		comp "glibc check: chrooting is permited"
		rc=0
	else
		perr "glibc check: chrooting is not permited"
		rc=1
	fi
	if [ "$1" != "all" ]; then
		echo; exit $rc
	fi
fi

if [ "$1" == "open" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing open${2+ $2}..."
	if [ ! -e busybox.tar.bz2 ]; then
		echo
		perr "ERROR: source archive not present, run $myname download"
		echo
		realexit 1
	fi
	if [ "$2" == "" -o "$2" == "all" ]; then
		ctype="nosuid"
	elif [ "$2" == "nosuid" ]; then
		ctype="nosuid"
	elif [ "$2" == "suid" ]; then
		ctype="suid"
	else
		echo
		warn "USAGE: $myname open [suid|nosuid]"
		echo
		realexit 1
	fi
	if [ ! -d src ]; then
		mod=1
		tar xjf busybox.tar.bz2
		mv -f busybox-$version src
		rm -f .patches_applied
	fi
	if [ ! -e .patches_applied -a ! -e .patches_applied.close ]; then
		mod=1
		cd $mydir/src
		for i in ../patches/*.patch; do
			err=0
			warn "\nApplying $(basename $i)"
			if ! patch -Np1 -fi $i; then
				echo "************ Using -p0 **************"
				if ! patch -Np0 -fi $i; then
					perr "\nApplying $(basename $i) failed"
					realexit 1
				fi
			fi
		done
		cd ..
		touch .patches_applied
		chownuser .patches_applied
	fi
	if [ "$mod" == "1" ]; then
		cd $mydir/src
		echo
		warn "select configure $ctype"
		setconfig $ctype
		cd ..
	fi
	echo
	chownuser src
fi

if [ "$1" == "compile" ]; then
	if ! which tce-load >/dev/null; then
		echo
		perr "ERROR: compiling busybox into host enviroment"
		perr "       the resulting image may fail to boot"
		echo
		echo "Press ENTER to continue or CTRL-C to stop"
		echo
		read
	fi
	done=1
	cd $mydir
	info "busybox.sh executing compile..."
	warn "compile with: $compile"
	checkfordir src open
	echo
	cd src

	warn "cleaning"
	rm -rf _install rootfs
	make clean

	warn "configure nosuid"
	setconfig nosuid
	usermake oldconfig
	warn "compile nosuid"
	usermake

	dd if=busybox >/dev/null
	cd ..
	if [ -e $bb_bin_pkg ]; then
		mv -f $bb_bin_pkg $bb_bin_pkg.bak
	fi
fi

function binary_prepare() {
	done=1
	cd $mydir
	info "busybox.sh in binary_prepare()..."
	if [ ! -e $bb_bin_pkg ]; then
		checkfordir src open

		cd src
		rm -rf _install rootfs
		if [ ! -e .config.old ]; then
			usermake oldconfig
		fi
		usermake install
		mv _install rootfs

		cd rootfs
		mkdir -p etc bin
		chmod u+s bin/busybox
		cp -f ../../busybox.conf etc
		chmod 0444 etc/busybox.conf
		cp -f ../../busybox.suid bin
		chmod 0555 bin/busybox.suid
		chown -R root.root .

		tar cjf ../../$bb_bin_pkg .
		cd ../..
		chownuser $bb_bin_pkg
	else
		return 1
	fi
	return 0
}

if [ "$1" == "install" ]; then
	done=1
	cd $mydir
	binary=0; binary_prepare || binary=1
	info "busybox.sh executing install..."

	$tcdir/rootfs.sh open || exit 1
	rtdir=$($tcdir/rootfs.sh open)
	echo "$rtdir"
	rtdir=$(echo "$rtdir" | sed -ne "s,^opened folder: \(.*\),\1,p")
	if [ "$rtdir" == "" -o ! -d "$tcdir/$rtdir" ]; then
		echo
		perr "ERROR: $myname $1 failed, abort"
		echo
		realexit 1
	fi
	pwd
	tar xjf $bb_bin_pkg -C $tcdir/$rtdir

	cd $tcdir/$rtdir
	sed -i "s,busybox.suid,busybox," $(find etc/init.d -type f)
	missing=$(ls -alR | grep -e " -> busybox.suid" || true)
	if [ "$missing" != "" ]; then
		echo
		perr "ERROR: this missing applet(s) still refere to busybox.suid, abort"
		echo
		echo "$missing"
		echo
		realexit 1
	fi

	if false && [ $binary -eq 0 ]; then
		if which tce-load >/dev/null; then
			libcrypt=$(realpath /lib/libcrypt.so.1)
			libcrypto=$(basename $libcrypt)
			echo; ldd bin/busybox
			if echo "$libcrypto" | grep -q "libcrypt.so.1"; then
				echo
				warn "WARNING: host libcrypt.so.1 inheritance, trying to fix"
				echo
				cp -f $libcrypt lib
				ln -sf $libcrypto lib/libcrypt-2.*.so
			fi
		else
			libs=$(ldd bin/busybox | sed -ne "s,.* => \(/[^ ]*\) .*,\\1,p")
			libcrypt=$(echo "$libs" | grep "libcrypt.so.1")
			libcrypto=$(readlink $libcrypt)
			echo; ldd bin/busybox
			if echo "$libcrypto" | grep -q "libcrypt.so.1"; then
				echo
				warn "WARNING: libcrypt.so.1 host/guest mismatch, trying to fix"
				echo
				cp -f $(dirname $libcrypt)/$libcrypto lib
				ln -sf $libcrypto lib/libcrypt-2.*.so
			fi
		fi
	fi

	cd - >/dev/null
	$tcdir/rootfs.sh close
	chownuser .	
	cd ../..	
fi

if [ "$1" == "editconfig" ]; then
	done=1
	cursdir=/tmp/tcloop/ncursesw
	if [ -d $cursdir -a -d ${cursdir}-dev ]; then
		if [ ! -d /tmp/tcloop/pkg-config ]; then
			ln -sf $cursdir/usr/local/lib/* /usr/lib
			ln -sf ${cursdir}-dev/usr/local/lib/* /usr/lib
			ln -sf ${cursdir}-dev/usr/local/bin/* /usr/bin
			ln -sf ${cursdir}-dev/usr/local/include/* /usr/include
		fi
	fi
	cd $mydir
	info "busybox.sh executing editconfig..."
	checkfordir src open
	cd src
	usermake menuconfig
	chownuser .
	cd ..
fi

if [ "$1" == "saveconfig" ]; then
	done=1
	cd $mydir
	ctype=$(cat src/.config.type 2>/dev/null)
	info "busybox.sh executing saveconfig${ctype+ $ctype}..."
	checkconfig $ctype
	if [ ! -d src ]; then
		echo
		perr "ERROR: src folder does not exist, run $myname open"
		echo
		realexit 1
	fi
	mkdir -p orig
	cat config.$ctype >orig/.config
	if diff -pruN orig/.config src/.config >config.$ctype.patch; then
		warn "Nothing to save, current config has not been modified"
		rm -rf config.$ctype.patch
		realexit 0
	fi
	chownuser config.$ctype.patch
	warn "New config has been saved in config.$ctype.patch"
	rm -rf orig
fi

if [ "$1" == "update" ]; then
	done=1
	if [ ! -e $bb_bin_pkg ]; then
		cd $mydir
		checkfordir src open
		cd src
		if [ ! -e .config.type -o ! -e .config ]; then
			info "busybox.sh executing update..."
			echo
			perr "ERROR: run $myname compile first, abort"
			echo
			realexit 1
		fi
		ctype=$(cat .config.type 2>/dev/null)
		info "busybox.sh executing update${ctype+ $ctype}..."
		warn "compile with: $compile"
		checkconfig $ctype
		rm -rf _install rootfs
		if [ ! -e .config.old ]; then
			usermake oldconfig
		fi
		usermake
		dd if=busybox >/dev/null
		cd ..
	fi
	$mydir/$myname install quiet
fi

if [ "$1" == "close" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing close..."
	checkfordir src open
	cd src
	if [ -e .config ]; then
		cat .config > ../config.nosuid
		chownuser ../config.nosuid
	fi
	sudo rm -rf _install rootfs .config*
	make clean
	cd ..
	mv src busybox-$version
	tar cjf busybox.tar.bz2 busybox-$version
	mv .patches_applied .patches_applied.close
	rm -rf busybox-$version
fi

if [ "$1" == "clean" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing clean..."
	rm -rf src .patches_applied
fi

if [ "$1" == "distclean" ]; then
	done=1
	cd $mydir
	info "busybox.sh executing distclean..."
	rm -f busybox.tar.bz2 .patches_applied*
	rm -f config.suid config.nosuid
	rm -rf src
	for i in $(grep -e "^/busybox/patches/" ../.gitignore); do
		rm -f ../$i
	done
fi

if [ "$done" != "1" ]; then
	usage
fi

echo
comp "$myname $1 completed"
echo
realexit 0


