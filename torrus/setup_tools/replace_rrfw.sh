#!/bin/sh

# replace all ocurrences of RRFW and rrfw to Torrus and torrus

IN=$1
sed -e 's/RRFW/Torrus/g' -e 's/rrfw/torrus/g' $IN >/tmp/$$
mv /tmp/$$ $IN

