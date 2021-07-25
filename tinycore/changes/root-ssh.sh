#!/bin/ash
#
# Autore: Roberto A. Foglietta <roberto.foglietta@altran.it>
#

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

set -e

echo
echo -e "root\nroot\n" | passwd root >/dev/null

sed -i "s/#\(PermitRootLogin\) .*/\1 yes/"  /usr/local/etc/ssh/sshd_config

sshd=$(which sshd)
pid=$(pgrep $sshd || true)
if [ "$pid" == "" ]; then
	$(which sshd)
else
	kill -HUP $pid
fi

echo
echo "#################################################################"
echo "#  WARNING: by now, this system is easily vulnerable by remote  #"
echo "#           please, reboot as soon as possible or if unsure     #"
echo "#################################################################"
echo
echo "            >>> SSH user: root,   password: root <<<"
echo "            >>> SSH user: tc, password: tinycore <<<"
echo
