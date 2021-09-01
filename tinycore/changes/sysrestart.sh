#!/bin/ash

tclabel=$1

function gettcdev() {
	blkid --label $tclabel
}

[ ! "$tclabel" ] && exit 1

while gettcdev; do
	sleep 5
done >/dev/null
sleep 3
reboot.sh

