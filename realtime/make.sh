#!/bin/bash -Ee

export wdir=$(dirname $(readlink -f $0))
export myname=$(basename $0)
export param=$1

function onerror() {
	local rc=$?
	echo
	echo "ERROR: $myname failed${2+ in $2()} at line $1, rc: $rc"
	echo
	exit 1
}

cd $wdir
trap 'onerror $LINENO $FUNCNAME' ERR
cd $wdir

source ../tinycore/tinycore.conf
alias

if [ "$KERN" == "5.10.3" ]; then
	rtver=tr22
	rtfullver=5.10.4-rt22
elif [ "$KERN" == "5.15.10" ]; then
	rtver=rt24
	rtfullver=$KERN-$rtver
else
	echo
	echo "ERROR: linux version $KERN is not supported, abort!"
	echo
	exit 1
fi

if [ "$1" == "distclean" ]; then
	done=1
	$0 clean

	echo "Deleting the downloaded stuff ..."
	rm -f config-$KERN-tinycore$ARC sorter.sh
	rm -f linux-$KERN-patched.txz
	rm -f Module.symvers-$KERN-tinycore$ARCH.gz
	rm -f patch-$rtfullver.patch.gz

	echo "Deleting the kernel folder ..."
	rm -rf linux-$KERN
fi

if [ "$1" == "download" -o "$1" == "all" ]; then
	done=1
	echo "Downloading sorter.sh ..."
	wget -c https://raw.githubusercontent.com/robang74/sorter/master/sorter.sh
#	wget -c https://raw.githubusercontent.com/tinycorelinux/sorter/master/sorter.sh
#	sed -i "s,ln -s /usr,ln -sf /usr," sorter.sh
	chmod a+x sorter.sh

	echo "Downloading kernel tinycore stuff ..."
	ver=$KERN-tinycore$ARCH
	for i in config-$ver Module.symvers-$ver.gz linux-$KERN-patched.txz; do
		wget -c $tcrepo/release/src/kernel/$i
	done

	echo "Downloading real-time patch ..."
	rtrepo="https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt"
	rtrepo="-O patch-$KERN-rt.patch.gz $rtrepo"
	wget -c $rtrepo/${KERN::-3}/older/patch-$rtfullver.patch.gz
fi

if [ "$1" == "clean"  -o "$1" == "all" ]; then
	done=1
	echo "Cleaning ..."
	rm -f modules$ARCH.gz vmlinuz *.tcz*
	rm -f *.moddeps base_modules.tgz*
	rm -f config-$KERN-tinycore$ARCH
	rm -f patch-$KERN-rt.patch.gz
#	rm -rf tmp
fi

if [ "$1" == "prepare"  -o "$1" == "all" ]; then
	done=1
	echo "Preparing the kernel and patching it ..."
	if [ -d linux-$KERN ]; then
		echo
		echo "ERROR: folder 'linux-$KERN' exists, run distclean"
		echo
		exit 1
	fi
	time if true; then
		tar xf linux-$KERN-patched.txz
		cd linux-$KERN
		cp -f ../config-$KERN-tinycore$ARCH .config
		zcat ../patch-$KERN-rt.patch.gz | patch -p1
		patch -p1 < ../config-$KERN-tinycore$ARCH.patch
		make oldconfig
	fi >/dev/null
	cd ..
fi

if [ "$1" == "compile"  -o "$1" == "all" ]; then
	done=1
	echo "Compiling the kernel and modules ..."
	if [ ! -d linux-$KERN ]; then
		echo
		echo "ERROR: folder 'linux-$KERN' not exist, run prepare"
		echo
		exit 1
	fi
	cd linux-$KERN
	time make -j$(nproc)
	cd ..
fi

if [ "$1" == "install"  -o "$1" == "all" ]; then
	done=1
	echo "Installing the vmlinuz ..."
	if [ ! -d linux-$KERN ]; then
		echo
		echo "ERROR: folder 'linux-$KERN' not exist, run prepare"
		echo
		exit 1
	fi
	cd linux-$KERN
	cat arch/x86/boot/bzImage > $wdir/vmlinuz

	kername=$rtfullver-tinycore$ARCH
	d=lib/modules/$kername
	p=_install/usr/local
	rm -rf _install
	mkdir -p $p
	this=$PWD

	echo "Installing the modules ..."
	export INSTALL_MOD_PATH=$p
	time make -j$(nproc) modules_install >/dev/null
	rm -rf $p/$d/modules.* $p/$d/build $p/$d/source

	echo "Creating modules.gz and related TCZs ..."
	cd ..
	time $wdir/sorter.sh $kername $this/_install >/dev/null
fi

trap - ERR
shift || true
if [ "$done" != "1" ]; then
	echo
	echo "USAGE: $myname <distclean|download|clean|prepare|compile|install|all>"
	echo
	exit 1
elif [ "$1" != "" ]; then
	$0 "$@"
fi

