#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

function usage() {
	echo "USAGE: $myname [download|open|compile|install|close|clean|distclean]"
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
	wget -c $confsuid -O config.suid
	wget -c $confnosuid -O config.nosuid
	wget -c $source -O busybox.tar.bz2
elif [ "$1" == "open" ]; then
	tar xjf busybox.tar.bz2
	mv busybox-$version src
elif [ "$1" == "compile" ]; then
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
elif [ "$1" == "install" ]; then
	rtdir=$($tcdir/rootfs.sh open | sed -ne "s,^opened folder: \(.*\),\1,p")
	if [ "$rtdir" == "" -o ! -d "$tcdir/$rtdir" ]; then
		echo
		echo "ERROR: $myname $1 failed, abort"
		echo
		exit 1
	fi
	cd src/rootfs
	sudo cp -arf * $tcdir/$rtdir
	$tcdir/rootfs.sh close
elif [ "$1" == "close" ]; then
	cd src
	sudo rm -rf _install rootfs
	make clean
	cd ..
	mv src busybox-$version
	tar cjf busybox.tar.bz2 busybox-$version
elif [ "$1" == "clean" ]; then
	sudo rm -rf src
elif [ "$1" == "distclean" ]; then
	sudo rm -rf src
	rm -f busybox.tar.bz2
	rm -f config.suid config.nosuid
else
	usage; exit 1
fi

echo
echo "$myname $1 completed"
echo

