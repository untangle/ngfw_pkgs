#! /bin/sh

DISABLERS=/tmp/disablers
TRIALS=/tmp/trials

dpkg --get-selections "*disabler*" | awk '{print $1}' > ${DISABLERS}
cat ${DISABLERS} | xargs apt-get remove --purge --yes

dpkg --get-selections "*trial30*" | awk '{print $1}' > ${TRIALS}
rm -f /usr/share/untangle/conf/trials/*.expired
cat ${TRIALS} | xargs apt-get install --yes

/etc/init.d/untangle-vm restart

rm -f ${DISABLERS} ${TRIALS}
