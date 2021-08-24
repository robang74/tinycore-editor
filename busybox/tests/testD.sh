#!/bin/ash

function cmdevalfalse() {
	command eval false
	echo "FUNCNAME='$FUNCNAME' == 'cmdevalfalse'"
}

cat >shrc <<EOF
   :
   :
   :
EOF

if [ "$(echo {1..2})" == "1 2" ]; then
	echo "shell: bash"
	ENV=shrc bash -ic 'echo LINENO=$LINENO'
else
	echo "shell: busybox ash"
	ENV=shrc src/busybox ash -ic 'echo LINENO=$LINENO'
fi
rm -f shrc

set -E
exec 2>&1

trap ")" ERR
trap
echo "-----------"
cmdevalfalse
echo "FUNCNAME='$FUNCNAME' == ''"
echo "-----------"
trap "echo ERR" ERR
trap
echo "still running"
false
echo $?
echo "still running after false"

trap '
command eval ")"
false
' ERR
false
echo done
