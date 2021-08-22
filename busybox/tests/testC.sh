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

function myexit() {
	echo "hello by $FUNCNAME() at line $LINENO"
	exit $1
}

function myecho() {
	echo "hello by $FUNCNAME() at line $LINENO"
}

function myfalse() {
	echo "hello by $FUNCNAME() at line $LINENO"
	false
}

function mytrue() {
	echo "hello by $FUNCNAME() at line $LINENO"
	true
}

trap 'onerror $LINENO $FUNCNAME' ERR
trap 'echo exit in $FUNCNAME\(\) at line $LINENO == 32 not 60 because set -E, EXITSTATUS: $?' EXIT

set -E

myecho && echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"
mytrue && echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"
myfalse && echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"
myfalse || echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"
mytrue; echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"
myfalse; echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO, EXITSTATUS: $?"
echo "FUNCNAME = $FUNCNAME, LINENO = $LINENO"


set -e
myfalse
echo "should not print this!"

