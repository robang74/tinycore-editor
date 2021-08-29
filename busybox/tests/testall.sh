#!/bin/bash

if [ "$1" != "" ]; then
	all="$@"
else
	all="$(echo {1..9} {A..G})"
fi

for i in $all; do
	test -e tests/test$i.sh || continue
	echo "################## TEST $i ##################"
	src/busybox ash tests/test$i.sh
	echo "exit code $?"
	echo "#############################################"
	echo
done >tests/bbash.txt

for i in $all; do
	test -e tests/test$i.sh || continue
	echo "################## TEST $i ##################"
	bash tests/test$i.sh
	echo "exit code $?"
	echo "#############################################"
	echo
done >tests/obash.txt

echo "Results in tests/obash.txt tests/bbash.txt"
