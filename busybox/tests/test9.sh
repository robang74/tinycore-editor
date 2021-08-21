#!/bin/ash

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
