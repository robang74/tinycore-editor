#!/bin/bash
#
# Author: Roberto A. Foglietta
#

tmpdir=tccustom.tmp

set -e

cd $(dirname $0)

if [ "$1" == "" ]; then
	set -- 32 64
fi

for i in $@; do
	rm -rf $tmpdir
	mkdir $tmpdir
	cp -arf tccustom/common/* $tmpdir
	cp -arf tccustom/$i/* $tmpdir
	cd $tmpdir
	tar czf ../tccustom$i.tgz .
	cd ..
	if which advdef >/dev/null; then
		advdef -z3 tccustom$i.tgz
	fi
done
rm -rf $tmpdir

