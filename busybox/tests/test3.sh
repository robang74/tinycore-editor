#!/bin/ash

function realexit() {
	trap - EXIT
	exit $1
}

function perr() {
	echo -e "\e[1;31m$@\e[0m"
}

function onerror() {
	rc=$?
#	echo
	perr "ERROR: $(basename $0) failed${2+ in $2()} at line $1, rc: $rc" 
	echo "$FUNCNAME() at line $LINENO == 16"
#	echo
#	realexit $rc
}

function mytest() {
	echo "hello at line $LINENO == 22"
	false
}

trap 'onerror $LINENO $FUNCNAME' ERR
trap 'echo exit at line $LINENO == 30 with pippo but not pluto' EXIT
set -e
echo "ciao! at line $LINENO == 29"
mytest
echo "mytest should have failed at line 30"
echo "pippo"
set -E
mytest



echo "pluto at line 38"
