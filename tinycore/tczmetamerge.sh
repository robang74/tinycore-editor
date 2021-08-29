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

function unmountall() {
	echo -ne "\tUnmounting ..."
	declare -i n=1
	while ! umount ? ?? ???; do
		mount | grep -qe "/tinycore/tcz/[0-9]* type squashfs" || break
		sleep 0.5
		echo -n "."
	done 2>/dev/null
	rm -rf u e [1-9] [1-9][0-9] [1-9][0-9][0-9]
	echo
}

function metamerge() {
	declare i n udir meta list
	meta=$1
	shift
	test "$1" == "" && return 0
	if [ "$meta" == "test" ]; then
		warn "$meta-meta.tcz skipping by default"
		echo
		return 0
	fi
	list=$(echo "$@" | sed -e "s/KERNEL/$KERN-tinycore$ARCH/g")
	list=$(echo "$list" | tr ' ' \\n | sort | uniq)
	merged=$(echo "$merged" | tr \\n ' ')

	cd tcz
	UNMNTDIR=$PWD
	rmdir ? ?? ??? 2>/dev/null || true
	if [ -e $meta-meta.tcz ]; then
		cd ..
		comp "$meta-meta.tcz exists, skipping"
		deps+=" $meta-meta.tcz"
		echo
		return 0
	fi
	info "Merging $meta in $meta-meta.tcz ..."
	for i in $list; do
		i=${i/.tcz/}.tcz
		if [ ! -e $i ]; then
			echo
			perr "\tERROR: $i is missing, abort"
			echo
			warn "\tSUGGEST: run ./provides/tcgetdistro.sh and retry"
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
	trap 'rm -f $meta-meta.tcz; unmountall' EXIT
	for i in $list; do
		i=${i/.tcz/}.tcz
		if echo "$merged" | grep -q " $i"; then
			warn "\tskipping: $i in $meta"
			continue
		elif [ ! -s $i ]; then
			warn "\tskipping: $i is null"
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

	unmountall
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

cd $(dirname $0)

source tinycore.conf

for i in $tczmeta; do
	test -e tcz/$i.list || continue
	if [ conf.d/$i.lst -nt tcz/$i.list ]; then
		echo
		perr "ERROR: conf.d/$i.lst is newer than tcz/$i.list"
		echo
		echo "If you did changes then delete and rebuild the meta packages"
		echo "otherwise touch tinycore/tcz/$i.list to ignore this message"
		echo
		warn "SUGGEST: run '$(basename $0) clean' to delete them all"
		warn "         run 'sudo $(basename $0)' to redo them all"
		echo
		exit 1
	fi
done

if [ "$1" == "clean" ]; then
	rm -f tcz/*-meta.tcz* 
	rm -f tcz/tczmeta.list
	exit 0
fi

if [ "$1" != "force" ]; then
	if [ ! -e tcz/tczmeta.list ]; then
		cd tcz
		for i in $(ls -1 *-meta.tcz); do
			i=${i/-meta.tcz/}
			echo -n "$i "
		done >tczmeta.list 2>/dev/null
		chownuser tczmeta.list
		cd - >/dev/null
	fi

	tczmnow=$(cat tcz/tczmeta.list)
	tczmnow=${tczmnow% }
	n=$(echo -n "$tczmeta" | wc -c)
	tczmnow=$(echo "$tczmnow" | head -c$n)
	if [ "$tczmnow" != "" -a "$tczmnow" != "$tczmeta" ]; then
		echo
		perr "ERROR: tczmeta is changed in tinycore.conf since last time"
		echo
		warn "SUGGEST: delete all the meta packages and redo them all"
		warn "         run '$(basename $0) clean' to delete them all"
		warn "         run 'sudo $(basename $0)' to redo them all"
		echo
		exit 1
	fi
	[ "$1" == "test" ] && exit 0
fi

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

echo
echo "gsettings for avoid automount windows displaying..."
prev=$(su -l $SUDO_USER -c "gsettings get org.gnome.desktop.media-handling automount-open 2>/dev/null")
su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open false 2>/dev/null"
echo

rc=0
deps=""
merged=""
for i in $tczmeta; do
	if [ ! -e conf.d/$i.lst ]; then
		rc=1
		break
	fi
	list=$(cat conf.d/$i.lst)
	list=$(get_tczlist_full tcz $list)
	metamerge $i $list
	merged+=" $list"
done
echo "$tczmeta" > tcz/tczmeta.list
chownuser tcz/tczmeta.list

su -l $SUDO_USER -c "gsettings set org.gnome.desktop.media-handling automount-open $prev 2>/dev/null"
exit $rc
