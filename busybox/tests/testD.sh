#!/bin/ash

function cmdevalfalse() {
	command eval false
	echo "FUNCNAME='$FUNCNAME' == 'cmdevalfalse'"
}

set -E; exec 2>&1

trap ")" ERR
trap
echo "-----------"
cmdevalfalse
echo "FUNCNAME='$FUNCNAME' == ''"
echo "-----------"
trap "echo ERR" ERR
trap
echo still running
false
echo $?
echo still running after false
