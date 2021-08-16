#!/bin/ash

pwd=$(realpath $(dirname $0))

. $pwd/funcs.sh




















trap 'onerror $LINENO $FUNCNAME' ERR
trap 'echo exit at line $LINENO == 34 with pippo but not pluto' EXIT

echo "ciao! at line $LINENO == 29"
mytest
echo "mytest should have failed at line 30"
echo "pippo"
set -e
false



echo "pluto at line 38"
