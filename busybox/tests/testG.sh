#!/bin/ash

function myfalse() {
	false
}

trap 'rc=$?; echo ERR at in $FUNCNAME at $LINENO, exit with $rc; exit $rc' ERR
set -E
myfalse
