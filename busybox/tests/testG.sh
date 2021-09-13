#!/bin/ash

function myfalse() {
	false
}

function myfault() {
	command eval ")"
}

function myflase() {
	flase
}

set 'echo "error in $FUNCANME at line $LINENO"' ERR
exec 2>&1

myfault
echo "FUNCNAME='$FUNCNAME'"
myflase
echo "FUNCNAME='$FUNCNAME'"

trap 'rc=$?; echo ERR at in $FUNCNAME at $LINENO, exit with $rc; exit $rc' ERR
set -E
myfalse
