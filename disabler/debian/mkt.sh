#!/bin/sh



pkgs="`cat control | grep Package | awk '{print $2}'`"

for i in $pkgs ; do 
    tran="`echo $i | awk -F\. '{print $1}' `"
    tname="`echo $tran | awk -F- '{print $1}' `"

    echo "Making pkgs for" $tname " ... " 

    for templatefile in `ls template-disabler*` ; do 
        newfile="`echo $templatefile | sed -s \"s/template-disabler/$tran/\" `"
        echo $newfile
        cat $templatefile | sed -s "s/template-disabler/$tran/" | sed -s "s/template/$tname/" > $newfile
    done
done


