#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

tcdev=$(blkid | grep -e "=.TINYCORE. " | cut -d: -f1)
tcdir=$(mount | grep -e "$tcdev on" | cut -d' ' -f3)
echo $tcdev:$tcdir
