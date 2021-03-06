#!/bin/ash

function funcone() {
	trap 'echo ERR ONE, $FUNCNAME at line $LINENO' ERR
	false
}

function functwo() {
	trap "echo ERR TWO, $FUNCNAME at line $LINENO" ERR
	funcone
}

function functhree() {
	false
	functwo
	if [ "$(echo {1..2})" != "1 2" ]; then
		echo "ERR ONE, functhree at line 15 is acceptable in busybox ash"
	fi
	false
}

function funcfour() {
	trap -- ERR
	false
}

funcone
if [ "$(echo {1..2})" != "1 2" ]; then
	echo "ERR ONE, at line 27 is acceptable in busybox ash"
fi
echo "funcone exit status = $? == 1"
false

echo "-----------------01----------------------"

set -E

funcone
echo "funcone exit status = $? == 1"
false

echo "-----------------02----------------------"

functwo
false

echo "-----------------03----------------------"

functhree
if [ "$(echo {1..2})" != "1 2" ]; then
	echo "in this test bash seems incoherent about functhree line 15"
fi
false

echo "-----------------04----------------------"

funcfour
false

echo "-----------------05----------------------"

set +E

functwo
if [ "$(echo {1..2})" != "1 2" ]; then
	echo "ERR ONE, at line 64 is acceptable in busybox ash"
fi
false

echo "-----------------06----------------------"

functhree
false

echo "-----------------07----------------------"

funcfour
false

echo "-----------------08----------------------"

trap "echo ERR MAIN" ERR

false
funcone

echo "-----------------09----------------------"

functwo
false

echo "-----------------10----------------------"

functhree
false

echo "-----------------11----------------------"

funcfour
false

echo "-----------------12----------------------"

trap "echo ERR MAIN" ERR
set -E

false
funcone

echo "-----------------13----------------------"

functwo
false

echo "-----------------14----------------------"

functhree
if [ "$(echo {1..2})" != "1 2" ]; then
	echo "in this test bash seems incoherent about functhree line 15"
fi
false

echo "-----------------15----------------------"

funcfour
false

echo "-----------------16----------------------"

function cleantrap() {
	false
	trap -- ERR
}

trap "echo ERR MAIN" ERR
trap
cleantrap
false

echo "-----------------17----------------------"

function myfault() {
	trap 'echo ERR $FUNCNAME at line $LINENO' ERR
	(:) >/access-denied
	if [ "$(echo {1..2})" != "1 2" ]; then
		echo "bash reports line 142 but fault is at line 144"
	fi
}

function myfault2() {
	trap 'echo ERR $FUNCNAME at line $LINENO' ERR
	command eval ")"
}

exec 2>&1

trap 'echo ERR $FUNCNAME at line $LINENO' ERR
trap 'echo EXIT $FUNCNAME at line $LINENO' EXIT

myfault

echo "-----------------18----------------------"

myfault2
command eval ")"
(:) >/access-denied

echo "-----------------19----------------------"

trap 'echo EXIT $FUNCNAME at line $LINENO == 176' EXIT

function myexit() {
	true
	if echo -n "exit 1 -"; then
		echo " now"
		exit 1
	fi
}

set -e
myexit

