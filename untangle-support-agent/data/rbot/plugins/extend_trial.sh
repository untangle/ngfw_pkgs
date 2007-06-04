#! /bin/sh

DISABLERS=/tmp/disablers
TRIALS=/tmp/trials

dpkg --get-selections "*disabler*" | awk '{print $1}' > ${DISABLERS}
cat ${DISABLERS} | xargs apt-get remove --purge --yes

dpkg --get-selections "*trial30*" | awk '{print $1}' > ${TRIALS}
rm -f /usr/share/metavize/conf/trials/*.expired
cat ${TRIALS} | xargs apt-get install --yes

/etc/init.d/mvvm restart

rm -f ${DISABLERS} ${TRIALS}
