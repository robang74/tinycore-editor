#!/bin/bash
set -e
cd $(dirname $0)
source ../tinycore.conf
echo
echo "Checking for last updates ..."
echo
f=$(basename $updates)
rm -f $f
wget $tcrepo/$updates
md5sum=$(md5sum $f | cut -d' ' -f1)
echo
if grep -q "$md5sum.*updatelist-${ARCH:-32}\.txt" updatelist.md5sum; then
	echo "OK: no need to update respect the repository"
else
	echo "ATTENTION: new updates available, need to run"
	echo
	echo "           ./tcupdatedb.sh && ./tcmkdepsdb.sh"
fi
echo
