#!/bin/ash

function realexit() {
	trap - EXIT
	exit $1
}

function setoinvalid() {
	false
	eval 'echo "$FUNCNAME LINENO=$LINENO == 10"; set -o invalid' 2>&1
}
function onerror() {
	rc=$?
#	echo
	echo "ERROR: $(basename $0) failed${2+ in $2()} at line $1, rc: $rc != 0" 
	echo "$FUNCNAME() at line $LINENO == 16"
#	echo
#	realexit $rc
}

function mytest() {
	echo "hello by $FUNCNAME() at line $LINENO == 22"
	false
	true
}
trap 'onerror $LINENO $FUNCNAME' ERR
trap 'echo exit in $FUNCNAME\(\) at line $LINENO == 37 with pippo but not pluto' EXIT
#exec 2>&1; set -x
echo "ciao! at line $LINENO == 29"
mytest
echo "pippo, exit status $? == 0"

echo "LINENO=$LINENO == 33, FUNCNAME='' == '$FUNCNAME'"
setoinvalid
echo "LINENO=$LINENO == 35, FUNCNAME='' == '$FUNCNAME'"
set -e
eval 'echo LINENO=$LINENO; set -o invalid' 2>&1
echo "pluto at line 38"
