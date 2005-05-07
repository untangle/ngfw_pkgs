#! /bin/sh

BASE_DIRECTORY=/var/www/metavize/pool/metavize
#PACKAGE_DIRECTORY=./packages
BACKUP_DIRECTORY=/var/www/metavize/backup
# BACKUP METHOD:
#  0 = show files to be removed (default)
#  1 = move files 
BACKUP_METHOD="1"

#full_destination_path_name()
#{
#    # get the full path destination name
#    if [ -z "$1" ]; then
#    # empty string
#	rval=""
#	return
#    fi
#    rval=$PACKAGE_DIRECTORY/$1
#}

#full_base_path_name()
#{
#    # find the most recent file for the base package name
#    if [ -z "$1" ]; then
#	# empty string
#	rval=""
#	return
#    fi
#
#    filename=$1
#    if [ "`echo $filename | cut -b 1-3`" = "lib" ]; then
#        directory="`echo $filename | cut -b 1-4`"
#    else 
#    	directory="`echo $filename | cut -b 1`"
#    fi
#
#    rval=$BASE_DIRECTORY/$directory/$filename
#}

is_file_in_list()
{
    in_file_list=$1
    in_file="$2"

    for ff in $in_file_list; do
        if [ "$in_file" = "$ff" ]; then
	    return 1
	fi
    done

    return 0
}

remove_file() {
    if [ $BACKUP_METHOD -eq "0" ]; then
        echo "backing up file: $1"
	return 0
    fi

    if [ ! -e $BACKUP_DIRECTORY ]; then
    	mkdir -p $BACKUP_DIRECTORY
    fi

    if [ $BACKUP_METHOD -eq "1" ]; then
        echo "moving $1 -> $BACKUP_DIRECTORY"
        mv $1 $BACKUP_DIRECTORY
    fi
}

remove_all_but_recent_n_files()
{
    # find the most recent file for the base package name
    if [ -z "$1" ]; then
	# empty string
	rval=""
	return
    fi

    filename=$1
    number_of_files=$2
    if [ "`echo $filename | cut -b 1-3`" = "lib" ]; then
        directory="`echo $filename | cut -b 1-4`"
    else 
    	directory="`echo $filename | cut -b 1`"
    fi

    current_dir="`pwd`"
    cd $BASE_DIRECTORY/$directory

    file_count=0
    total_files=`ls -lt --time-style long-iso "$filename"_*deb 2> /dev/null | awk '{print $8}' | wc -l`

    if [ $total_files -lt $number_of_files ]; then
        echo "$filename clean."
        cd $current_dir
        return
    	max_files=$total_files
    else
        max_files=$number_of_files
    fi

    file_list="$(ls -lt --time-style long-iso $filename_*deb | awk '{print $8}' | xargs echo | awk '{i=0; while(i++<'$max_files') print $i}')"
    total_file_list="$(ls -lt --time-style long-iso $filename_*deb | awk '{print $8}' | xargs echo)"

    for f in $total_file_list; do
        is_file_in_list "$file_list" $f
	if [ $? -ne "1" ]; then
	    remove_file $f
	fi
    done

    echo "$filename clean."
    cd $current_dir
}

cd $BASE_DIRECTORY
find . -type f -name "*.deb" -printf "%f\n" | sed -e "s/_.*//g" | sort | uniq > /tmp/pkgs

for package in `cat /tmp/pkgs`; do
    if [ ! -z $2 ]; then
    	BACKUP_METHOD="$2"
    fi
        remove_all_but_recent_n_files $package $1
done
