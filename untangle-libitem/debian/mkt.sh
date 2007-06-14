#!/bin/sh



pkgs="`cat control | grep Package | awk '{print $2}'`"

for i in $pkgs ; do 
    tran="`echo $i | awk -F\. '{print $1}' `"
    tname="`echo $tran | awk -F- '{print $1}' `"

    echo "Making pkgs for" $tname " ... " 

    for templatefile in `ls template-storeitem*` ; do 
        newfile="`echo $templatefile | sed -s \"s/template-storeitem/$tran/\" `"
        echo $newfile
        cat $templatefile | sed -s "s/template-storeitem/$tran/g" | sed -s "s/template/$tname/g" > $newfile
    done
done


