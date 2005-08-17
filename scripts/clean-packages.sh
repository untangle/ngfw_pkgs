#! /bin/sh

if [ $# -lt 3 ]; then
    echo "usage) $0 <basedir> <versioncount> <method>"
    echo "basedir        Base Directory (ie /var/www/metavize/)"
    echo "versioncount   Number of version to keep (ie 3)"
    echo "method         {move|delete|nothing}"
    exit 1
fi

BASE_DIRECTORY=$1/pool/metavize/
echo $BASE_DIRECTORY
shift
KEEPCOUNT=$1
shift
BACKUP_METHOD="$1"
shift

BACKUP_DIRECTORY=/pkgbackup


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
    if [ $BACKUP_METHOD = "nothing" ]; then
        echo "remove/backup $1"
        return 0
    fi

    if [ $BACKUP_METHOD = "move" ]; then
        if [ ! -e $BACKUP_DIRECTORY ]; then
            mkdir -p $BACKUP_DIRECTORY
        fi
        echo "moving $1 -> $BACKUP_DIRECTORY"
        mv $1 $BACKUP_DIRECTORY
    fi

    if [ $BACKUP_METHOD = "delete" ]; then
        echo "removing $1"
        rm -f $1 
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
    if [ "`echo ${filename} | cut -b 1-3`" = "lib" ]; then
        directory="`echo ${filename} | cut -b 1-4`"
    else 
    	directory="`echo ${filename} | cut -b 1`"
    fi

    current_dir="`pwd`"
    cd $BASE_DIRECTORY/$directory

    file_count=0
    total_files=`ls -lt --time-style long-iso ${filename}_*deb 2> /dev/null | awk '{print $8}' | wc -l`

    if [ $total_files -lt $number_of_files ]; then
        echo "${filename} clean."
        cd $current_dir
        return
    else
        max_files=$number_of_files
    fi

    file_list="$(ls -lt --time-style long-iso ${filename}_*deb | awk '{print $8}' | xargs echo | awk '{i=0; while(i++<'$max_files') print $i}')"
    total_file_list="$(ls -lt --time-style long-iso ${filename}_*deb | awk '{print $8}' | xargs echo)"

    for f in $total_file_list; do
        is_file_in_list "$file_list" $f
	if [ $? -ne "1" ]; then
	    remove_file $f
	fi
    done

    echo "${filename} clean."
    cd $current_dir
}

cd $BASE_DIRECTORY
find . -type f -name "*.deb" -printf "%f\n" | sed -e "s/_.*//g" | sort | uniq > /tmp/pkgs

for package in `cat /tmp/pkgs`; do
    remove_all_but_recent_n_files $package $KEEPCOUNT
done
