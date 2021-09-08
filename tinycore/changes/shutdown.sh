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
echo "Shutdown the system in 3 seconds..."
echo

sleep 3 || exit 1

nohup ash -c 'sleep 1; echo o > /proc/sysrq-trigger' >/dev/null 2>&1 &
sleep 0.5
killall dropbear 2>/dev/null
killall sshd 2>/dev/null
