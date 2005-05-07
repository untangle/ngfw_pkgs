#! /bin/sh

if [ -z $DEBDEST ] ; then
    DIR=metavize
else
    DIR=$DEBDEST
fi

DESTINATION=/var/www/$DIR
echo $DESTINATION
DISTRIBUTION=testing
COMPONENT=metavize
OVERRIDE=override.${DISTRIBUTION}.${COMPONENT}
ARCH=i386

#
# Create Debian repository filesystem
#

create_dir()
{
  [ -d $1 ] || mkdir -p $1 || exit -1
}

create_dir ${DESTINATION}/${COMPONENT}
 
create_dir ${DESTINATION}/dists/${DISTRIBUTION}

create_dir ${DESTINATION}/dists/${DISTRIBUTION}/${COMPONENT}/binary-${ARCH}
 
create_dir ${DESTINATION}/indices
                                                                                
create_dir ${DESTINATION}/pool/${COMPONENT}

#
# Copy packages to destination
#
while ! [ -z "$1" ]
do
  if [ "${1##*.}" != "deb" ]
  then
    echo WARNING: \"$1\" does not have .deb extension
    shift
    continue
  fi
  file=`basename $1`
  if [ "${file:0:3}" == "lib" ] ; then
    create_dir ${DESTINATION}/pool/${COMPONENT}/${file:0:4}
    if [ ! -f ${DESTINATION}/pool/${COMPONENT}/${file:0:4}/${file} ] ; then
        echo "Copying $1 to ${DESTINATION}/pool/${COMPONENT}/${file:0:4}/"
        cp -af $1 ${DESTINATION}/pool/${COMPONENT}/${file:0:4}/
    fi
  else
    create_dir ${DESTINATION}/pool/${COMPONENT}/${file:0:1}
    if [ ! -f ${DESTINATION}/pool/${COMPONENT}/${file:0:1}/${file} ] ; then
        echo "Copying $1 to ${DESTINATION}/pool/${COMPONENT}/${file:0:1}/"
        cp -af $1 ${DESTINATION}/pool/${COMPONENT}/${file:0:1}/
    fi
  fi
  file=
  shift
done

