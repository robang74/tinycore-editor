#!/bin/ash

function myfalse() {
	false
	true
}

function myfault() {
	command eval ")"
	true
}

function myflase() {
	flase
	true
}

trap 'echo "ERR in $FUNCNAME at $LINENO"' ERR
exec 2>&1

myfault
echo "FUNCNAME='$FUNCNAME'"
echo "------1------"

myflase
echo "FUNCNAME='$FUNCNAME'"
echo "------2------"

set -E

trap 'echo "ERR in $FUNCNAME at $LINENO"; command eval ")"' ERR
myfalse
echo "FUNCNAME='$FUNCNAME'"
echo "------3------"

#trap 'echo "ERR in $FUNCNAME at $LINENO"; eval ")"' ERR
#myfalse
#echo "FUNCNAME='$FUNCNAME'"
#echo "------4------"

trap 'rc=$?; echo "ERR at in $FUNCNAME at $LINENO, exit with $rc"; exit $rc' ERR
myfalse
