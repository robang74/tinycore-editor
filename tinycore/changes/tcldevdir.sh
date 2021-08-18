#!/bin/ash
#
# Author: Roberto A. Foglietta
#

tcdev=$(readlink /etc/sysconfig/tcdev)
tcdir=$(readlink /etc/sysconfig/tcdir)
echo $tcdev:$tcdir
