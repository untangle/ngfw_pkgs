#!/bin/bash
GOCR=gocr
if test -x ./gocr; then GOCR=./gocr; fi
for ifile in $*; do
  tfile=$(echo ${ifile} | sed 's/\.gz$//')
  tfile=$(echo ${tfile} | sed 's/\.p.m$/\.txt/')
  echo -ne "test ${ifile} ${tfile}               \n"
  if ${GOCR} ${ifile} | diff -u ${tfile} -; then true; else echo ""; fi
done
