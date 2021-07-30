#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

tcdev=$(readlink -f /etc/sysconfig/tcdev)
tcdir=$(readlink -f /etc/sysconfig/tcdir)
echo $tcdev:$tcdir
