#! /bin/sh

if [ $# -lt 1 ] ; then
    echo "usage: $0 <dir ex: /var/www/metavize>"
    exit
fi

DESTINATION=$1
DISTRIBUTION=testing
COMPONENT=metavize
OVERRIDE=override.${DISTRIBUTION}.${COMPONENT}
ARCH=i386

cp -a `dirname $0`/${OVERRIDE} ${DESTINATION}/indices/

#
# Generate Packages.gz
#
cd ${DESTINATION}

echo "Building package list for \"${DESTINATION}\""

dpkg-scanpackages pool/${COMPONENT} indices/${OVERRIDE} > \
	dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages 2> /tmp/out 
if [ $? -ne 0 ] ; then exit ; fi

grep -v "newer version" /tmp/out | grep -v "ignored" | grep -v "is repeat"

cat dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages | \
	gzip -9 > dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}/Packages.gz
if [ $? -ne 0 ] ; then exit ; fi

