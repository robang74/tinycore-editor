#!/bin/bash

function metamerge() {
	declare i n udir meta list
	meta=$1
	shift
	[ "$1" == "" ] && return 0
	list="$@"
	cd tcz
	if [ -e $meta-meta.tcz ]; then
		cd ..
		return 0
	fi
	echo "Merging $meta in $meta-meta.tcz ..."
	for i in $list; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if [ ! -e $i ]; then
			echo -e "\tERROR: $i is missing, abort"
			cd ..
			return 1
		fi
	done
	n=1
	trap 'umount u ${udir//:/ } 2>/dev/null' EXIT
	for i in $list; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if echo "$merged" | grep -wq $i; then
			echo -e "\tskipping: $i in $meta"
			continue
		fi
		echo -e "\tprocessing: $i"
		mkdir -p $n
		mount $i $n
		merged+=" $i"
		udir+="$n:"
		let n++
	done
	udir=${udir%:}
	mkdir -p u
	unionfs-fuse $udir u
	mksquashfs u $meta-meta.tcz -comp xz -Xbcj x86 >/dev/null
	touch $meta-meta.tcz.dep
	sync
	du -ks $meta-meta.tcz
	udir=${udir//:/ }
	umount u $udir
	rmdir u $udir
	echo
	cd ..
	trap - EXIT
}

set -e

if [ "$USER" != "root" ]; then
	echo
	echo "ERROR: $(basename $0) requires root privileges"
	echo
	exit 1
fi

source tinycore.conf

echo
merged=""
for i in $tczmeta; do
	if [ ! -e conf.d/$i.lst ]; then
		exit 1
	fi
	list=$(cat conf.d/$i.lst | tr \\n ' ')
	metamerge $i $list
	merged+=" $list"
done

