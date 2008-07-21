#! /bin/bash



pkgs="`cat control | grep 'Package:' | awk '{print $2}'`"

for i in $pkgs ; do 
    item="`echo $i | sed 's/untangle-libitem-//'`"
    
    echo "Making pkgs for" $item " ... " 

    for templatefile in `ls *-template*` ; do 
        newfile="`echo $templatefile | sed -s \"s/template/$item/\" `"
        echo $newfile
        cat $templatefile | sed -s "s/template/$item/g"  > $newfile
    done
done


