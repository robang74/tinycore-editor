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

function usage() {
	info "USAGE: $myname \$target"
	echo
	echo -e "\t targets:"
	echo -e "\t\t download         (retrieve source)"
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

function setconfig() {
	if [ "$1" != "" ]; then
		cat ../config.$1 >.config
		if [ -e ../config.$1.patch ]; then
			patch -Np1 -i ../config.$1.patch
		fi
	fi
}

function chownuser() {
	chown -R $SUDO_USER.$SUDO_USER "$@"
}

function realexit() {
	trap - EXIT
	exit $1
}

#function atexit() {
#	echo
#	perr "ERROR: $myname failed at line $1, abort"
#	echo
#	realexit 1
#}

###############################################################################

if [ "$USER" != "root" ]; then
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
source $tcdir/tinycore.conf
source busybox.sh.conf

arch=${ARCH:--m32}
arch=${arch/64/-m64}
archtune=${arch/-m64/$cputune64}
archtune=${archtune/-m32/$cputune32}
compile="CFLAGS='$arch $archtune $ccopts' LDFLAGS=$arch make -j$(nproc)"

###############################################################################

#PS4='DEBUG: $((LASTNO=$LINENO)): '
#exec 2> >(grep -ve "^D*EBUG: ")
#trap 'atexit $LASTNO' EXIT
#set -ex

set -e

if [ "$2" != "quiet" ]; then
	echo
	warn "Working folder is $PWD"
	warn "Architecture: x86 ${arch/-m/} bit"
	warn "Version: $version"
	echo
fi

if [ "$1" == "download" ]; then
	done=1
	cd $mydir
	info "executing download..."
	echo
	wget -c $confsuid -O config.suid
	wget -c $confnosuid -O config.nosuid
	wget -c $source -O busybox.tar.bz2
	mkdir -p patches
	for i in $patchlist; do
		wget -c $tcbbsrc/$i -O patches/$i
	done
	chownuser patches *suid *.bz2
fi

if [ "$1" == "open" -o "$1" == "all" ]; then
	done=1
	cd $mydir
	info "executing open${2+ $2}..."
	if [ ! -e busybox.tar.bz2 ]; then
		echo
		perr "ERROR: source archive not present, run $myname download"
		echo
		realexit 1
	fi
	if [ "$2" == "" -o "$2" == "all" ]; then
		ctype=""
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
		tar xjf busybox.tar.bz2
		mv busybox-$version src
	fi
	if [ ! -e .patches_applied -a ! -e .patches_applied.close ]; then
		cd $mydir/src
		for i in ../patches/*.patch; do
			err=0
			warn "\nApplying $(basename $i)"
			if ! timeout 1 patch -Np1 -i $i; then
				echo "************ Using -p0 **************"
				if ! timeout 1 patch -Np0 -i $i; then
					perr "\nApplying $(basename $i) failed"
					realexit 1
				fi
			fi
		done
		cd ..
		touch .patches_applied
		chownuser .patches_applied
	fi
	cd $mydir/src
	setconfig $ctype
	echo $ctype > .config.type
	cd ..
	echo
	chownuser src
fi

if [ "$1" == "compile" -o "$1" == "all" ]; then
	done=1
	cd $mydir
	info "executing compile..."
	warn "compile with: $compile"
	checkfordir src open
	echo
	cd src

	warn "cleaning"
	sudo rm -rf _install rootfs
	make clean

	warn "configure nosuid"
	setconfig nosuid
	echo nosuid > .config.type
	make oldconfig
	warn "compile nosuid"
	eval $compile install
	mv _install rootfs

	chownuser .
	cd ..
fi

if [ "$1" == "install" -o "$1" == "all" ]; then
	done=1
	cd $mydir
	info "executing install..."
	checkfordir src open
	cd src
	checkfordir rootfs compile
#	set +x
	rtdir=$($tcdir/rootfs.sh open)
	echo "$rtdir"
	rtdir=$(echo "$rtdir" | sed -ne "s,^opened folder: \(.*\),\1,p")
#	set -x
	if [ "$rtdir" == "" -o ! -d "$tcdir/$rtdir" ]; then
		echo
		perr "ERROR: $myname $1 failed, abort"
		echo
		realexit 1
	fi

	cd rootfs
	mkdir -p etc
	chmod u+s bin/busybox
	cp -f ../../busybox.conf etc
	chown -R root.root .
	cp -arf * $tcdir/$rtdir

	cd $tcdir/$rtdir
	rm -f bin/busybox.suid
	sed -i "s,busybox.suid,busybox," etc/init.d/busybox-aliases
	sed -i "s,chmod u+s /bin/busybox.suid,chmod u+s," etc/init.d/tc-config
	missing=$(ls -alR | grep busybox.suid || true)
	if [ "$missing" != "" ]; then
		echo
		perr "ERROR: this missing applet(s) still refere to busybox.suid, abort"
		echo
		echo "$missing"
		echo
		realexit 1
	fi
	cd - >/dev/null

	$tcdir/rootfs.sh close
	chownuser .	
	cd ../..	
fi

if [ "$1" == "editconfig" ]; then
	done=1
	cd $mydir
	info "executing editconfig..."
	checkfordir src open
	cd src
#	set +x
	make menuconfig
#	set -x
	chownuser .
	cd ..
fi

if [ "$1" == "saveconfig" ]; then
	done=1
	cd $mydir
	ctype=$(cat src/.config.type 2>/dev/null)
	info "executing saveconfig${ctype+ $ctype}..."
	case $ctype in
	suid|nosuid|"")
		;;
	default)
		echo
		perr "ERROR: src/.config.type value is unknown"
		echo
		realexit 1
	esac
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
	cd $mydir
	ctype=$(cat src/.config.type 2>/dev/null)
	info "executing update${ctype+ $ctype}..."
	warn "compile with: $compile"
	case $ctype in
	suid|nosuid|"")
		;;
	default)
		echo
		perr "ERROR: src/.config.type value is unknown"
		echo
		realexit 1
	esac
	checkfordir src open
	cd src
	checkfordir rootfs compile
	eval $compile install
	ctype=${ctype/nosuid/}
	ctype=${ctype/suid/.suid}
	dd if=busybox of=rootfs/bin/busybox$ctype
	chownuser .
	cd ..
	$mydir/$myname install quiet
fi

if [ "$1" == "close" ]; then
	done=1
	cd $mydir
	info "executing close..."
	checkfordir src open
	cd src
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
	info "executing clean..."
	rm -rf src .patches_applied
fi

if [ "$1" == "distclean" ]; then
	done=1
	cd $mydir
	info "executing distclean..."
	rm -f busybox.tar.bz2 .patches_applied*
	rm -f config.suid config.nosuid
	rm -rf src
	cd patches
	rm -f $patchlist
	cd ..
fi

if [ "$done" != "1" ]; then
	usage
fi

echo
comp "$myname $1 completed"
echo
realexit 0


