#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function usage() {
	echo "USAGE: $myname [download|open|compile|install|close|all|clean|distclean]"
	echo
}

set -e

cd $(dirname $0)
myname=$(basename $0)
tcdir=$(realpath ../tinycore)
source $tcdir/tinycore.conf
source busybox.conf

arch=${ARCH:--m32}
arch=${arch/64/-m64}
archtune=${arch/-m64/-mtune=generic}
archtune=${archtune/-m32/-march=i486 -mtune=i686}
compile="CPPFLAGS=$arch LDFLAGS=$arch $ccopts $ccxopts make -j$(nproc)"

echo
echo "Working folder is $PWD"
echo "Architecture: x86 ${arch/-m/} bit"
echo "Version: $version"
echo

if [ "$1" == "download" ]; then
	done=1
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
	if [ ! -e busybox.tar.bz2 ]; then
		echo
		echo "ERROR: source archive not present, run $myname download"
		echo
		exit 1
	fi
	if [ ! -d src ]; then
		tar xjf busybox.tar.bz2
		mv busybox-$version src
		cd src
		for i in $patchlist; do
			if ! timeout 1 patch -Np1 -i ../patches/$i; then
				echo "************ Using -p0 **************"
				patch -Np0 -i ../patches/$i
			fi
		done
		cd ..
	fi
fi
if [ "$1" == "compile" -o "$1" == "all" ]; then
	done=1
	cd src

	sudo rm -rf _install rootfs
	make clean

	cat ../config.nosuid >.config
	make oldconfig
	eval $compile install

	mv _install rootfs
	sudo chown -R root.root rootfs

	cat ../config.suid >.config
	make oldconfig
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
	cd src
	if [ ! -d rootfs ]; then
		echo
		echo "ERROR: rootfs folder does not exist, run $myname compile"
		echo
		exit 1
	fi
	rtdir=$($tcdir/rootfs.sh open | sed -ne "s,^opened folder: \(.*\),\1,p")
	if [ "$rtdir" == "" -o ! -d "$tcdir/$rtdir" ]; then
		echo
		echo "ERROR: $myname $1 failed, abort"
		echo
		exit 1
	fi
	cd rootfs
	sudo cp -arf * $tcdir/$rtdir
	$tcdir/rootfs.sh close
fi
if [ "$1" == "update" -o "$1" == "all" ]; then
	done=1
	cd src
	if [ "$2" == "" -o "$2" == "nosuid" ]; then
		ver=nosuid
	elif [ "$2" == "suid" ]; then
		ver=suid
	else
		echo
		echo "USAGE: myname update [suid|nosuid]"
		echo
		exit 1
	fi
	if [ ! -d rootfs ]; then
		echo
		echo "ERROR: rootfs folder does not exist, run $myname compile"
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
	$0 install
fi
if [ "$1" == "close" ]; then
	done=1
	cd src
	sudo rm -rf _install rootfs
	make clean
	cd ..
	mv src busybox-$version
	tar cjf busybox.tar.bz2 busybox-$version
fi
if [ "$1" == "clean" ]; then
	done=1
	sudo rm -rf src
fi
if [ "$1" == "distclean" ]; then
	done=1
	sudo rm -rf src patches
	rm -f busybox.tar.bz2
	rm -f config.suid config.nosuid
fi

if [ "$done" != "1" ]; then
	usage; exit 1
fi

echo
echo "$myname $1 completed"
echo

