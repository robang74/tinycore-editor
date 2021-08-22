#!/bin/bash

for i in {1..9} {A..C}; do
	test -e tests/test$i.sh || continue
	echo "################## TEST $i ##################"
	src/busybox ash tests/test$i.sh
	echo "#############################################"
	echo
done >tests/bbash.txt

for i in {1..9} {A..C}; do
	test -e tests/test$i.sh || continue
	echo "################## TEST $i ##################"
	bash tests/test$i.sh
	echo "#############################################"
	echo
done >tests/obash.txt

echo "Results in tests/obash.txt tests/bbash.txt"
