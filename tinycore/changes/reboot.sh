#!/bin/ash
#
# Author: Roberto A. Foglietta
#

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

echo 1 > /proc/sys/kernel/sysrq
echo s > /proc/sysrq-trigger
echo u > /proc/sysrq-trigger

echo
echo "Syncing, timeout 60 seconds..."
echo

timeout 60 sync

echo
echo "Reboot the system in 3 seconds..."
echo

sleep 3 || exit 1

echo b > /proc/sysrq-trigger
