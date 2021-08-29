#!/bin/ash

exec 2>&1

trap 'eval ")"' ERR
false
echo hello 1
if [ "$(echo {1..2})" != "1 2" ]; then
	echo "The next instruction is deadly for unpatched busybox ash also"
fi
eval ")"
echo hello 2
