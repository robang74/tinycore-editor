#!/bin/bash

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
	declare user guid
	user=$SUDO_USER
	user=${user:-$USER}
	guid=$(grep -e "^$user:" /etc/passwd | cut -d: -f3-4)
	chown -R $guid "$@"
}

function metamerge() {
	declare i n udir meta list
	meta=$1
	shift
	[ "$1" == "" ] && return 0
	list="$@"

	cd tcz
	rmdir ? ?? ??? 2>/dev/null || true
	if [ -e $meta-meta.tcz ]; then
		cd ..
		comp "$meta-meta.tcz exists, skipping"
		deps+=" $meta-meta.tcz"
		return 0
	fi
	info "Merging $meta in $meta-meta.tcz ..."
	for i in $list; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if [ ! -e $i ]; then
			echo
			perr "\tERROR: $i is missing, abort"
			echo
			cd ..
			return 1
		fi
	done

	n=1
	rm -rf e
	tceinst=e/usr/local/tce.installed
	mkdir -p $tceinst
	chmod 0775 $tceinst
	chown 0.50 $tceinst
	trap 'rm -f $meta-meta.tcz; umount u ${udir//:/ } 2>/dev/null' EXIT
	for i in $list; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		if echo "$merged" | grep -q " $i"; then
			warn "\tskipping: $i in $meta"
			continue
		fi
		echo -e "\tprocessing: $i"
		fname=$tceinst/${i%????}
		touch $fname
		chown 1001.50 $fname
		mkdir -p $n
		mount $i $n
		merged+=" $i"
		udir+="$n:"
		let n++
	done
	if [ -e ../conf.d/$meta-meta ]; then
		cat ../conf.d/$meta-meta >$tceinst/$meta-meta
		chown 1001.50 $tceinst/$meta-meta
		chmod a+x $tceinst/$meta-meta
	fi

	mkdir -p u
	unionfs-fuse ${udir}e u

	cd u/usr/local/tce.installed
	for i in *; do
		if [ -x $i ]; then
			if ! grep -qe "\$wd/$i" $meta-meta 2>/dev/null; then
				echo
				perr "ERROR: \$wd/$i is not present in $meta-meta"
				echo
				cd - >/dev/null
				exit 1
			elif [ "$i" != "$meta-meta" ]; then
				comp "\tloadscript: $i"
			fi
		fi
	done
	cd - >/dev/null

	echo
	info "Compressing $meta-meta.tcz ..."
	for i in $list; do echo $i; done > $meta.new
	sed -i "s,$KERN-tinycore$ARCH,KERNEL," $meta.new
	cat $meta.new | sort | uniq >$meta.list
	rm -f $meta.new
	mksquashfs u $meta-meta.tcz -comp xz -Xbcj x86 >/dev/null
	echo "$deps" | tr ' ' \\n | egrep . > $meta-meta.tcz.dep || true
	md5sum $meta-meta.tcz >$meta-meta.tcz.md5.txt
	chownuser $meta-meta.tcz* $meta.list
	du -ks $meta-meta.tcz

	n=1
	udir=${udir//:/ }
	echo -e "\tUnmounting ..."
	while ! umount u $udir; do 
		sleep 0.5;
		let n++
		[[ $n -gt 5 ]] && break
	done 2>/dev/null
	rm -rf u $udir e
	echo
	cd ..
	deps+=" $meta-meta.tcz"
	trap - EXIT
}

function get_tczlist_full() {
	declare deps i tczdir=$1 getdeps
	getdeps=$tczdir/../provides/tcdepends.sh
	shift
	for i in $@; do
		i=${i/.tcz/}.tcz
		i=${i/KERNEL/$KERN-tinycore$ARCH}
		deps+=" $($getdeps $i | grep -e "^$i:" | cut -d: -f2-)"
		deps+=" $(cat $tczdir/$i.dep) $i"
	done
	for i in $deps; do echo $i; done | sort | uniq
}

###############################################################################

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

set -e

if [ "$USER" != "root" ]; then
	echo
	echo "ERROR: $(basename $0) requires root privileges"
	echo
	exit 1
fi

if ! which unionfs-fuse >/dev/null; then
	echo
	echo "ERROR: $(basename $0) requires unionfs-fuse"
	echo
	exit 1
fi

source tinycore.conf

echo
deps=""
merged=""
for i in $tczmeta; do
	if [ ! -e conf.d/$i.lst ]; then
		exit 1
	fi
	list=$(cat conf.d/$i.lst | tr \\n ' ')
	list=$(get_tczlist_full tcz $list)
	metamerge $i $list
	merged+=" $list"
done
echo

