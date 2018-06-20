#! /bin/bash

# dumbed-down, minimalist version of ngfw_pkgtools.git/make-build.sh
# (no versioning, etc), just so TravisCI can test the build of our
# packages

set -e

awk '$2 == "stretch" {print $1}' build-order.txt | while read d ; do
 grep -qE '^Architecture:.*(amd64|any|all)' "$d"/debian/control
 pushd "$d"
 mk-build-deps -i -t 'apt-get -y'
 dpkg-buildpackage -us -uc
 popd
done
