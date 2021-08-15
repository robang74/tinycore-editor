#!/bin/ash

pwd=$(realpath $(dirname $0))

. $pwd/funcs.sh



trap "echo this is a multi-line trap which begins at line $LINENO == 9
echo exit at line \$LINENO == 34 with pippo but not pluto
echo this is a multi-line trap which ends at line $LINENO == 11" EXIT














trap 'onerror $LINENO $FUNCNAME' ERR

echo "funcname in script: '$FUNCNAME' == ''"
echo "ciao! at line $LINENO == 29"
mytest
echo "mytest should have failed at line 23"
echo "pippo"
set -e
false



echo "pluto at line 38"
