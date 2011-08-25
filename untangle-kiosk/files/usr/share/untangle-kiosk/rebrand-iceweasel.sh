#!/bin/dash

#
# Replaces "Iceweasel" in window title with nothing
# http://www.winmatrix.com/forums/index.php?/topic/9032-customize-mozilla-firefox-window-name/
#

mkdir /tmp/newjar
cd /tmp/newjar

jar x < /usr/share/iceweasel/chrome/en-US.jar
sed -i 's/Iceweasel//g' ./locale/branding/brand.dtd
jar c . > /usr/share/iceweasel/chrome/en-US.jar

cd /
rm -rf /tmp/newjar
