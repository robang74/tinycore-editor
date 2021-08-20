#!/bin/bash

for i in {1..8}; do
	echo "################## TEST $i ##################"
	src/busybox ash tests/test$i.sh
	echo "#############################################"
	echo
done >tests/bbash.txt

for i in {1..8}; do
	echo "################## TEST $i ##################"
	bash tests/test$i.sh
	echo "#############################################"
	echo
done >tests/obash.txt

echo "Results in tests/obash.txt tests/bbash.txt"
