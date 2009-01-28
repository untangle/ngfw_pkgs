#! /bin/bash

set -e

LOG_FILE=/var/tmp/upgrade61.sh

exec > >(tee -a $LOG_FILE) 2>&1

DEBIAN_MIRROR_HOST="10.0.11.16" # debian
DEBIAN_MIRROR="http://${DEBIAN_MIRROR_HOST}/debian"
UNTANGLE_MIRROR_HOST="10.0.0.105" # mephisto
UNTANGLE_MIRROR="http://${UNTANGLE_MIRROR_HOST}/public/lenny"

APT_GET="/usr/bin/apt-get"
APT_GET_OPTIONS="-o DPkg::Options::=--force-confnew --yes --force-yes"

STEPS="(setup|sysvinit|remove|etch|lenny|untangle|finish)"
LAST_STEP=""

## helper functions
usage() {
  echo "$0 [-i]"
  echo " -i : interactive mode"
  exit 1
}

fail() {
    echo "upgrade failed - leaving divert in place, retrying"
    # Try again
    exec /usr/bin/uvm.sh
    exit 1
}

undo_divert() {
    target=/usr/bin/uvm.sh
    div=$(dpkg-divert --list $target)
    if [ -n "$div" ] && [ -z "${div%%*by untangle-appliance-int}" ]; then
        rm -f $target
	dpkg-divert --remove --rename --package untangle-appliance-int --divert $target.distrib $target
    fi
    target=/usr/bin/uvm-restart
    div=$(dpkg-divert --list $target)
    if [ -n "$div" ] && [ -z "${div%%*by untangle-appliance-int}" ]; then
        rm -f $target
	dpkg-divert --remove --rename --package untangle-appliance-int --divert $target.distrib $target
    fi
}

aptgetyes() {
  if [ "$1" = "--trust-me" ] ; then
    shift
    yes="echo Yes, do as I say!"
    $yes | $APT_GET $APT_GET_OPTIONS $@
  else
    $APT_GET $APT_GET_OPTIONS $@
  fi
}

aptgetupdate() {
  $APT_GET update
  aptgetyes install untangle-keyring
  $APT_GET update
}

removePackages() {
  COLUMNS=200 dpkg -l | awk '/^ii.+'"$1"'/ {print $2}' | xargs $APT_GET $APT_GET_OPTIONS remove --purge
}

stepName() {
  echo "## $1 (`date -Iseconds`)"
}

## various steps to run during the upgrade
stepSetup() {
  stepName "stepSetup"

  wall <<EOF

Untangle 6.1 upgrade beginning.  Progress may be monitored with:
  # tail -f $LOG_FILE

Once the upgrade has completed, the Untangle Server will reboot automatically.
EOF

  echo "Sleeping 120 seconds.  This is your chance to adjust sources.list (if necessary)"
  sleep 120

  # set debconf to critical/noninteractive
  echo debconfig debconf/priority select critical | debconf-set-selections
  echo debconfig debconf/frontend select Noninteractive | debconf-set-selections

  # increase apt cache size
  echo 'APT::Cache-Limit 12582912;' >> /etc/apt/apt.conf

  # start sshd or not
  ls /etc/rc*/S*ssh > /dev/null 2>&1
  START_SSHD=$?

  # unhold dpkg
  echo dpkg install | dpkg --set-selections

  # keep track of the untangle packages that are already installed,
  # as some of the stepCleanUp will remove them
  case $(uname -m) in
    x86_64) ARCH="amd64" ;;
    *) ARCH="686" ;;
  esac
  UNTANGLE_PACKAGES="linux-image-2.6.26-1-untangle-${ARCH}"

  for p in untangle-gateway-light untangle-gateway untangle-client-local ; do
    dpkg -l $p | grep -qE '^ii' && UNTANGLE_PACKAGES="$UNTANGLE_PACKAGES $p"
  done
}

stepSysVInit() {
  stepName "stepSysVInit"

  # remove the knoppix epoch'ed sysvinit
  aptgetyes --trust-me remove sysvinit

  # create a dummy update-rc.d
  cat >> /usr/sbin/update-rc.d <<EOF
#! /bin/sh
exit 0
EOF
  chmod 755 /usr/sbin/update-rc.d

  # get the etch sysvinit
  echo "deb $DEBIAN_MIRROR etch main contrib non-free" >| /etc/apt/sources.list
  aptgetupdate
  aptgetyes --trust-me install sysvinit sysv-rc
}

stepRemoveUnwantedPackaged() {
  stepName "stepRemoveUnwantedPackaged"

  # knoppix
  removePackages "k(noppi)?x"
  removePackages "(lilo|pppconfig|cloop-utils)"

  # this "remove X 3.3 packages" (and some untangle-* packages, see above)
  removePackages "3\.3\.6"
  # xfce4, as we only want xfwm4 later on
  removePackages "libxfcegui"
}

stepDistUpgradeToEtch() {
  stepName "stepDistUpgradeToEtch"

  # install the newer postgres 7.4 from etch, as it follows the naming
  # convention in /etc/
  aptgetyes install postgresql-7.4 postgresql-common postgresql postgresql-client-7.4 python-psycopg python libapache2-mod-python python-pycurl

  aptgetyes dist-upgrade

  # free up some space
  apt-get clean
}

stepDistUpgradeToLenny() {
  stepName "stepDistUpgradeToLenny"

  # vanilla one will be installed in a minute
  rm /etc/kernel-img.conf

  # exim4
  echo "dc_localdelivery='mail_spool'" >> /etc/exim4/update-exim4.conf.conf

  # dist-upgrade to lenny
  echo "deb $UNTANGLE_MIRROR nightly main premium upstream" >| /etc/apt/sources.list
  aptgetupdate
  aptgetyes dist-upgrade
}

stepReinstallUntanglePackages() {
  stepName "stepReinstallUntanglePackages"

  # untangle packages from lenny
  [ -n "$UNTANGLE_PACKAGES" ] && aptgetyes install $UNTANGLE_PACKAGES libnfnetlink0

  # restore ssh state
  [ "$START_SSHD" = 0 ] && update-rc.d ssh defaults

  # dist-upgrade again
  aptgetyes dist-upgrade

  # free up some space
  apt-get clean
}

stepFinish() {
  stepName "stepFinish"

  # motd
  ln -sf /var/run/motd /etc/motd

  echo "#########################################"
  echo "All done."

  reboot
}

## main
date -Iseconds

while getopts "ih" opt ; do
  case "$opt" in
    i) INTERACTIVE="true"
       echo "### Interactive mode ###"
       echo "### *foo*   --> step foo was run once."
       echo "### **foo** --> step foo was run twice."
       echo "### etc..." ;;
    h) usage ;;
    \?) usage ;;
  esac
done
shift $(($OPTIND - 1))

if [ $# -gt 0 ] ; then
  usage
fi

if [ -z "$INTERACTIVE" ] ; then
  stepSetup
  stepSysVInit
  stepRemoveUnwantedPackaged
  stepDistUpgradeToEtch
  stepDistUpgradeToLenny
  stepReinstallUntanglePackages
  stepFinish
else
  while true ; do
    echo
    read -p"Step (or '(quit|exit)') $STEPS : " answer
    echo "read: '$answer'"
    case "$answer" in
      quit|exit|bye) break ;;
      setup) stepSetup ;;
      sysvinit) stepSysVInit ;;
      remove) stepRemoveUnwantedPackaged ;;
      etch) stepDistUpgradeToEtch ;;
      lenny) stepDistUpgradeToLenny ;;
      untangle) stepReinstallUntanglePackages ;;
      finish) stepFinish ;;
    esac
    STEPS=${STEPS/$answer/*$answer*}
  done
fi
