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
	echo -e "\t\t download"
	echo -e "\t\t open"
	echo -e "\t\t compile (from scratch)"
	echo -e "\t\t install (into rootfs.gz)"
	echo -e "\t\t update [suid|nosuid]"
	echo -e "\t\t close"
	echo -e "\t\t all"
	echo -e "\t\t clean"
	echo -e "\t\t distclean"
	echo
}

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

set -e

mydir=$(dirname $0)
myname=$(basename $0)
cd $mydir

tcdir=$(realpath ../tinycore)
source $tcdir/tinycore.conf
source busybox.conf

arch=${ARCH:--m32}
arch=${arch/64/-m64}
archtune=${arch/-m64/-mtune=generic}
archtune=${archtune/-m32/-march=i486 -mtune=i686}
compile="CPPFLAGS=$arch LDFLAGS=$arch $ccopts $ccxopts make -j$(nproc)"

if [ "$2" != "quiet" ]; then
	echo
	warn "Working folder is $PWD"
	warn "Architecture: x86 ${arch/-m/} bit"
	warn "Version: $version"
	echo
fi

if [ "$1" == "download" ]; then
	done=1
	info "executing $1..."
	echo
	wget -c $confsuid -O config.suid
	wget -c $confnosuid -O config.nosuid
	wget -c $source -O busybox.tar.bz2
	mkdir -p patches
	for i in $patchlist; do
		wget -c $tcbbsrc/$i -O patches/$i
	done
fi
if [ "$1" == "open" -o "$1" == "all" ]; then
	done=1
	info "executing $1..."
	if [ ! -e busybox.tar.bz2 ]; then
		echo
		perr "ERROR: source archive not present, run $myname download"
		echo
		exit 1
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
			if ! timeout 1 patch -Np1 -i ../patches/$i; then
				echo "************ Using -p0 **************"
				if ! timeout 1 patch -Np0 -i $i; then
					perr "\nApplying $(basename $i) failed"
					exit 1
				fi
			fi
		done
		echo
		cd ..
		touch .patches_applied
	fi
fi
if [ "$1" == "compile" -o "$1" == "all" ]; then
	done=1
	info "executing $1..."
	echo
	cd $mydir/src
	warn "cleaning"
	sudo rm -rf _install rootfs
	make clean
	warn "configure nosuid"
	cat ../config.nosuid >.config
	make oldconfig
	warn "compile nosuid"
	eval $compile install

	mv _install rootfs
	sudo chown -R root.root rootfs

	warn "configure suid"
	cat ../config.suid >.config
	make oldconfig
	warn "compile suid"
	eval $compile install

	cd _install
	sudo chown root.root bin/busybox
	sudo chmod u+s bin/busybox
	sudo mv bin/busybox bin/busybox.suid
	for i in $(find . -type l); do
		ln -sf /bin/busybox.suid $i
	done
	sudo cp -arf * ../rootfs
	cd ..

	sudo rm -rf _install
	cd ..
fi
if [ "$1" == "install" -o "$1" == "all" ]; then
	done=1
	info "executing $1..."
	cd $mydir/src
	if [ ! -d rootfs ]; then
		echo
		perr "ERROR: rootfs folder does not exist, run $myname compile"
		echo
		exit 1
	fi
	rtdir=$($tcdir/rootfs.sh open)
	echo "$rtdir"
	rtdir=$(echo "$rtdir" | sed -ne "s,^opened folder: \(.*\),\1,p")
	if [ "$rtdir" == "" -o ! -d "$tcdir/$rtdir" ]; then
		echo
		perr "ERROR: $myname $1 failed, abort"
		echo
		exit 1
	fi
	cd rootfs
	sudo cp -arf * $tcdir/$rtdir
	$tcdir/rootfs.sh close
	cd ../..
fi
if [ "$1" == "update" ]; then
	done=1
	info "executing $1..."
	cd $mydir/src
	if [ "$2" == "" -o "$2" == "nosuid" ]; then
		ver=nosuid
	elif [ "$2" == "suid" ]; then
		ver=suid
	else
		echo
		warn "USAGE: myname update [suid|nosuid]"
		echo
		exit 1
	fi
	if [ ! -d rootfs ]; then
		echo
		perr "ERROR: rootfs folder does not exist, run $myname compile"
		echo
		exit 1
	fi
	n=$(diff ../config.$ver .config | wc -l)
	if [[ $n -gt 6 ]]; then
		cat ../config.$ver >.config
		make oldconfig
	fi
	eval $compile
	ver=${ver/nosuid/}
	ver=${ver/suid/.suid}
	sudo dd if=busybox of=rootfs/bin/busybox$ver
	cd ..
	$0 install quiet
fi
if [ "$1" == "close" ]; then
	done=1
	info "executing $1..."
	cd $mydir/src
	sudo rm -rf _install rootfs
	make clean
	cd ..
	mv src busybox-$version
	tar cjf busybox.tar.bz2 busybox-$version
	mv .patches_applied .patches_applied.close
fi
if [ "$1" == "clean" ]; then
	done=1
	info "executing $1..."
	sudo rm -rf src .patches_applied
fi
if [ "$1" == "distclean" ]; then
	done=1
	info "executing $1..."
	rm -f busybox.tar.bz2 .patches_applied*
	rm -f config.suid config.nosuid
	sudo rm -rf src
	cd patches
	rm -f $patchlist
	cd ..
fi

if [ "$done" != "1" ]; then
	usage; exit 1
fi

echo
comp "$myname $1 completed"
echo

