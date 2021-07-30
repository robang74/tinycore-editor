#!/bin/ash
#
# Author: Roberto A. Foglietta
#

export PATH=/home/tc/.local/bin:/usr/local/sbin:/usr/local/bin
export PATH=$PATH:/apps/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ "$USER" != "root" ]; then
	echo
	echo "This script requires being root, abort"
	echo
	exit 1
fi

bootrd="
M8D6jtiO0LwAfInmBleOwPv8vwAGuQAB86XqHwYAAFJStEG7qlUxyTD2+c0TchOB+1WqdQ3R6XMJ
ZscGjQa0QusVWrQIzROD4T9RD7bGQPfhUlBmMcBmmehmAOg1AU1pc3Npbmcgb3BlcmF0aW5nIHN5
c3RlbS4NCmZgZjHSuwB8ZlJmUAZTagFqEInmZvc29HvA5AaI4YjFkvY2+HuIxgjhQbgBAooW+nvN
E41kEGZhw+jE/76+fb++B7kgAPOlw2ZgieW7vge5BAAxwFNR9geAdANAid6DwxDi80h0W3k5WVuK
RwQ8D3QGJH88BXUiZotHCGaLVhRmAdBmIdJ1A2aJwuis/3ID6Lb/ZotGHOig/4PDEOLMZmHD6HYA
TXVsdGlwbGUgYWN0aXZlIHBhcnRpdGlvbnMuDQpmi0QIZgNGHGaJRAjoMP9yJ2aBPgB8WEZTQnUJ
ZoPABOgc/3ITgT7+fVWqD4Xy/rz6e1pfB/r/5OgeAE9wZXJhdGluZyBzeXN0ZW0gbG9hZCBlcnJv
ci4NCl6stA6KPmIEswfNEDwKdfHNGPTr/QAAAAAAAAAAAAAAAAAAAADZsspkAAA=
"
tcdev=$(readlink /etc/sysconfig/tcdev)
bkdev=${tcdev%1}

if [ ! -b "$bkdev" ]; then
	echo
	echo "ERROR: TinyCore USB device not found, abort!"
	echo
	exit 1
fi

if ! which base64 >/dev/null; then
	echo
	echo "ERROR: command base64 not found, abort!"
	echo
	exit 1
fi

if [ "$1" == "enable" ]; then
	if echo -n "$bootrd" | base64 -di >$bkdev; then
		echo
		echo "USB boot enabled on $bkdev"
		echo
	fi
elif [ "$1" == "disable" ]; then
	if dd if=/dev/zero bs=1 count=446 of=$bkdev; then
		echo
		echo "USB boot disabled on $bkdev"
		echo
		echo "To re-enable the USB key boot, do this:"
		echo
		echo "   on windows: use rufus with tcl-usb-boot-enable.gz"
		echo "   on linux  : zcat tcl-usb-boot-enable.gz > \$device"
		echo
	fi 2>/dev/null
else
	echo
	echo "USAGE: $(basename $0) enable|disable"
	echo
fi

