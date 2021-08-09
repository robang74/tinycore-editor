#!/bin/bash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

tmpdir=tccustom.tmp

set -e

cd $(dirname $0)

for i in 32 64; do
	rm -rf $tmpdir
	mkdir $tmpdir
	cp -arf tccustom/common/* $tmpdir
	cp -arf tccustom/$i/* $tmpdir
	cd $tmpdir
	tar czf ../tccustom$i.tgz .
	cd ..
done
rm -rf $tmpdir

