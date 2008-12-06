#! /bin/bash

echo -n "Updating cache: "
apt-get update > /dev/null 2>&1
echo "done."

apt-cache search untangle | awk '/^untangle/ {print $1}' | while read p ; do
  echo -n "."
  output=$(apt-get install -s $p 2>&1)
  if [ $? != 0 ] ; then
    echo
    echo "Error while installing $p:"
    echo -e $output
  fi
done

echo
