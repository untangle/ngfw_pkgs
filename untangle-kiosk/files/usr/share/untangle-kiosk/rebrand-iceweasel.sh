#! /bin/bash

# Replaces "Iceweasel" in window title with nothing
# http://www.winmatrix.com/forums/index.php?/topic/9032-customize-mozilla-firefox-window-name/
# 
# If you're curious about the "eval echo" thingie, because you *think*
# you know how shell works, try this:
#   http://compgroups.net/comp.unix.shell/bash-question-forcing-filename-expansion/506897

tmpDir="/tmp/newjar"
filesToRebrand="locale/{branding/brand.{dtd,properties},browser/appstrings.properties}"
jarFile="/usr/share/iceweasel/browser/chrome/en-US.jar"

rm -fr $tmpDir
mkdir $tmpDir
cd $tmpDir

unzip -q $jarFile
sed -i 's/Iceweasel//g' $(eval echo $filesToRebrand)
zip -rq $jarFile .

cd /
rm -rf $tmpDir
