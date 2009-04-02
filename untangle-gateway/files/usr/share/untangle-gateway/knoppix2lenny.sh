#! /bin/bash

BASENAME="upgrade61"

LOG_FILE=/var/log/uvm/${BASENAME}.log

exec >> $LOG_FILE 2>&1

DELAY=60

#DEBIAN_MIRROR_HOST="10.0.11.16" # debian
DEBIAN_MIRROR_HOST="http.us.debian.org" # http.us.debian.org; FIXME: uncomment before releasing
DEBIAN_MIRROR="${DEBIAN_MIRROR_HOST}/debian"
#UNTANGLE_MIRROR_HOST="10.0.0.105" # mephisto
UNTANGLE_MIRROR_HOST="updates.untangle.com" # updates.untangle.com; FIXME: uncomment before releasing
UNTANGLE_MIRROR="${UNTANGLE_MIRROR_HOST}/public/lenny"
#UNTANGLE_61_DISTRIBUTIONS="mclaren nightly"
UNTANGLE_61_DISTRIBUTIONS="mclaren" # FIXME: uncomment before releasing

UNTANGLE_CREDENTIALS_FILE="/var/log/uvm/${BASENAME}.credentials"
UNTANGLE_PACKAGES_TO_REINSTALL="untangle-gateway-light untangle-gateway untangle-client-local untangle-libitem-adconnector untangle-libitem-boxbackup untangle-libitem-branding untangle-libitem-clam untangle-libitem-commtouch untangle-libitem-firewall untangle-libitem-ips untangle-libitem-kav untangle-libitem-opensource-package untangle-libitem-openvpn untangle-libitem-pcremote untangle-libitem-phish untangle-libitem-policy untangle-libitem-portal untangle-libitem-premium untangle-libitem-professional-package untangle-libitem-protofilter untangle-libitem-reporting untangle-libitem-shield untangle-libitem-sitefilter untangle-libitem-spamassassin untangle-libitem-spyware untangle-libitem-support untangle-libitem-test untangle-libitem-trial14-adconnector untangle-libitem-trial14-boxbackup untangle-libitem-trial14-commtouch untangle-libitem-trial14-kav untangle-libitem-trial14-pcremote untangle-libitem-trial14-policy untangle-libitem-trial14-portal untangle-libitem-trial14-professional-package untangle-libitem-trial14-sitefilter untangle-libitem-trial14-support untangle-libitem-trial30-boxbackup untangle-libitem-trial30-kav untangle-libitem-trial30-portal untangle-libitem-trial30-professional-package untangle-libitem-update-service untangle-libitem-webfilter"
UNTANGLE_PACKAGES_FILE="/var/log/uvm/${BASENAME}.packages"

SHARE="/usr/share/untangle-gateway"

MIRRORS_LIST_ORIG="${SHARE}/debian-mirrors.txt"
MIRRORS_LIST="/var/log/uvm/debian-mirrors.txt"

APT_GET="/usr/bin/apt-get"
APT_GET_OPTIONS="-o DPkg::Options::=--force-confnew --yes --force-yes"

STEPS="(setup|sysvinit|remove|etch|lenny|untangle|finish)"
LAST_STEP=""

APACHE_HTML_PAGE="${SHARE}/${BASENAME}.html"
APACHE_JS_PAGE="${SHARE}/${BASENAME}.js"
APACHE_UPGRADE_HTML_DIR="/var/www"
APACHE_UPGRADE_HTML_PAGE="${APACHE_UPGRADE_HTML_DIR}/${BASENAME}.html"
APACHE_UPGRADE_JS_PAGE="${APACHE_UPGRADE_HTML_DIR}/${BASENAME}.js"
APACHE_UPGRADE_CONFIG="RedirectMatch 301 ^/webui.* /$(basename $APACHE_HTML_PAGE)"
APACHE_UPGRADE_CONFIG_FILE="/etc/apache2/conf.d/${BASENAME}"

SLAPD_BACKUP=/var/backups/untangle-ldap-`date -Iseconds`.ldif
SNMP_BACKUP=/var/backups/untangle-snmp-`date -Iseconds`.ldif

PACKAGES_TO_INSTALL="console-common console-data console-tools ed gcc-4.2-base groff-base info rsyslog libdaemons-ruby libdaemons-ruby1.8 libnetfilter-conntrack1 man-db manpages nano netcat-traditional vim-common vim-tiny"
PACKAGES_TO_REMOVE="apache-utils arpwatch cloop-module cloop-utils cpp-3.3 gcc-3.3-base cramfsprogs fdisk-udeb gamin gcc-4.1-base glibc-doc hotplug-utils hunt hwsetup ipx k3b-defaults klogd sysklogd modconf mouseconfig mousepad ndiswrapper netcat netcat6 ntp-simple nvi openbsd-inetd orinoco parted-bf powermgmt-base pppconfig prism54 prism54-nonfree python2.4 python2.4-minimal shellutils untangle-fakekdm untangle-libitem-router untangle-libmocha-ruby1.8 update xterm"

## helper functions
usage() {
  echo "$0 [-i]"
  echo " -i : interactive mode"
  exit 1
}

fail() {
    echo "upgrade failed - leaving divert in place, retrying in $DELAY seconds"
    echo "The output for the upcoming retry will be in a new log file,"
    echo "so you should 'tail -f /var/log/uvm/${BASENAME}.log' again to see it."
    
    # email out
    email "fail"

    # Try again
    sleep $DELAY
    exec /usr/bin/uvm
    exit 1
}

email() {
  subject="$(cat $UNTANGLE_CREDENTIALS_FILE | perl -pe 's/^(.{4}).+/$1/'): $1"
  cat $LOG_FILE | mailx -s "$subject" upgrades61logs@untangle.com
}

undo_divert() {
    target=/usr/bin/uvm
    div=$(dpkg-divert --list $target)
    if [ -n "$div" ] && [ -z "${div%%*by untangle-gateway}" ]; then
        rm -f $target
	dpkg-divert --remove --rename --package untangle-gateway --divert $target.distrib $target
    fi
    target=/usr/bin/uvm-restart
    div=$(dpkg-divert --list $target)
    if [ -n "$div" ] && [ -z "${div%%*by untangle-gateway}" ]; then
        rm -f $target
	dpkg-divert --remove --rename --package untangle-gateway --divert $target.distrib $target
    fi
    target=/usr/bin/rush
    div=$(dpkg-divert --list $target)
    if [ -n "$div" ] && [ -z "${div%%*by untangle-gateway}" ]; then
      rm -f $target
      dpkg-divert --remove --rename --package untangle-gateway --divert $target.distrib $target
    fi

    rm -f $APACHE_UPGRADE_HTML_PAGE $APACHE_UPGRADE_JS_PAGE $APACHE_UPGRADE_CONFIG_FILE
}

aptgetyes() {
  # try in download mode 5 times before dist-upgrade'ing
  case "$@" in
    *dist-upgrade*)
      for i in $(seq 5) ; do
	$APT_GET -d $APT_GET_OPTIONS $@
      done ;;
  esac

  if [ "$1" = "--trust-me" ] ; then
    shift
    yes="echo Yes, do as I say!"
    $yes | $APT_GET $APT_GET_OPTIONS $@ || fail
  else
    $APT_GET $APT_GET_OPTIONS $@ || fail
  fi

  # restore old dnsmasq.conf after a dist-upgrade
  case "$@" in
    *dist-upgrade*)
      cp -f /etc/dnsmasq.conf.untangle /etc/dnsmasq.conf
      /etc/init.d/dnsmasq restart ;;
  esac
}

aptgetupdate() {
  $APT_GET update
  aptgetyes install untangle-keyring
  $APT_GET update || fail
}

removePackages() {
  $APT_GET $APT_GET_OPTIONS remove --purge $@
}

removePackagesRegex() {
  COLUMNS=200 dpkg -l | awk '/^ii.+'"$1"'/ {print $2}' | xargs $APT_GET $APT_GET_OPTIONS remove --purge || fail
}

stepName() {
  echo "## $1 (`date -Iseconds`)"
}

## various steps to run during the upgrade
stepSetup() {
  stepName "stepSetup"

  DISPLAY=:0 feh --bg-scale ${SHARE}/desktop_background_upgrade-1024x768.png

  wall <<EOF

Untangle 6.1 upgrade beginning.  Progress may be monitored with:

  # tail -f $LOG_FILE

Or by visiting http://localhost/${BASENAME}.html

Once the upgrade has completed, the Untangle Server will reboot automatically.
EOF

  # the webui can't be accessed while we're upgrading
  cp -f $APACHE_HTML_PAGE $APACHE_UPGRADE_HTML_PAGE
  cp -f $APACHE_JS_PAGE $APACHE_UPGRADE_JS_PAGE
  ln -sf $LOG_FILE ${APACHE_UPGRADE_HTML_DIR}/
  echo $APACHE_UPGRADE_CONFIG >| $APACHE_UPGRADE_CONFIG_FILE
  a2ensite default
  /etc/init.d/apache2 restart

  [ -f ${MIRRORS_LIST} ] || cp -f ${MIRRORS_LIST_ORIG} ${MIRRORS_LIST}
  [ -f ${UNTANGLE_CREDENTIALS_FILE} ] || perl -ne 'if (m|//(.*?)\@updates\.untangle\.com|) { print $1 . "\n" ; exit  }' /etc/apt/sources.list >| ${UNTANGLE_CREDENTIALS_FILE}

  # set debconf to critical/noninteractive
  echo debconfig debconf/priority select critical | debconf-set-selections
  echo debconfig debconf/frontend select Noninteractive | debconf-set-selections

  # increase apt cache size
  echo 'APT::Cache-Limit 12582912;' >> /etc/apt/apt.conf

  # start sshd or not
  ls /etc/rc*/S*ssh > /dev/null 2>&1
  START_SSHD=$?

  # unhold dpkg
  echo dpkg install | dpkg --set-selections || fail

  # keep track of the untangle packages that are already installed,
  # as some of the stepCleanUp will remove them
  case $(uname -m) in
    x86_64) ARCH="amd64" ;;
    *) ARCH="686" ;;
  esac
  UNTANGLE_PACKAGES="linux-image-2.6.26-1-untangle-${ARCH}"

  # either read the untangle packages to reinstall:
  #   - from dpkg itself
  #   - from a previously saved list
  if [ ! -f $UNTANGLE_PACKAGES_FILE ] ; then
    touch $UNTANGLE_PACKAGES_FILE
    for p in $UNTANGLE_PACKAGES_TO_REINSTALL ; do
      if dpkg -l $p | grep -qE '^ii' ; then
	UNTANGLE_PACKAGES="$UNTANGLE_PACKAGES $p"
	echo $p >> $UNTANGLE_PACKAGES_FILE
      fi
    done
  else
    while read $p ; do
      UNTANGLE_PACKAGES="$UNTANGLE_PACKAGES $p"
    done < $UNTANGLE_PACKAGES_FILE
  fi

  # backup our LDAP database
  slapcat -f /etc/untangle-ldap/slapd.conf -l ${SLAPD_BACKUP}

  # backup snmp settings
  cp -f /etc/snmp/snmpd.conf ${SNMP_BACKUP}

  # disable reporting
  UNTANGLE_REPORTING_TIDS="$(ucli instances | awk '/untangle-node-reporting/ {print $1}')"
  for tid in $UNTANGLE_REPORTING_TIDS ; do
    ucli stop $tid
  done

  # fix dnsmasq.conf syntax
  sed -i '/^domain-suffix/d' /etc/dnsmasq.conf /etc/dnsmasq.conf.dpkg-old || true
  if [ -f /etc/dnsmasq.conf.untangle ] ; then
    cp -f /etc/dnsmasq.conf.untangle /etc/dnsmasq.conf
  else
    cp -f /etc/dnsmasq.conf /etc/dnsmasq.conf.untangle
  fi
  /etc/init.d/dnsmasq restart

  # blank out Untangle sources
  rm -f /etc/apt/sources.list.d/untangle.list

  # stop atop
  /etc/init.d/atop stop

  # make sure dpkg is happy
  aptgetyes --trust-me -f install
  dpkg --configure -a
}

stepSysVInit() {
  stepName "stepSysVInit"
  
  if [ -n "$(dpkg -l sysvinit | grep 2.84-188)" ] ; then
    # remove the knoppix epoch'ed sysvinit
    aptgetyes --trust-me remove sysvinit

    # create a dummy update-rc.d
    cat >> /usr/sbin/update-rc.d <<EOF
#! /bin/sh
exit 0
EOF
    chmod 755 /usr/sbin/update-rc.d

    # get the etch sysvinit
    echo "deb http://$DEBIAN_MIRROR etch main contrib non-free" >| /etc/apt/sources.list
    aptgetupdate
    aptgetyes --trust-me install --purge sysvinit sysv-rc apt-spy
  fi
}

stepRemoveUnwantedPackaged() {
  stepName "stepRemoveUnwantedPackaged"

  ## knoppix
  removePackagesRegex "kn(oppi)?x"
  # even though we purge all the knoppix packages, we want to make
  # extra sure there are no knoppix remnants
  find /etc -name "*knoppix*" -exec rm -fr "{}" \;

  removePackagesRegex "(lilo|pppconfig|cloop-utils)"

  # this "remove X 3.3 packages" (and some untangle-* packages, see above)
  removePackagesRegex "xserver.*3\.3\.6"

  removePackages "xfce4-mixer-lib-alsa"

#   # xfce4, as we only want xfwm4 later on
#   removePackagesRegex "libxfcegui"
}

stepDistUpgradeToEtch() {
  stepName "stepDistUpgradeToEtch"

  # find the fastest etch source from a predefined set of mirrors
  apt-spy -t 7 -m ${MIRRORS_LIST} -o /etc/apt/sources.list -d etch -s ar,br,cl,cn,de,fr,hk,jp,kr,ru,tr,us,za
  grep -qE '^deb http' /etc/apt/sources.list || echo "deb http://$DEBIAN_MIRROR etch main contrib non-free" >| /etc/apt/sources.list
  cat /etc/apt/sources.list
  aptgetupdate

  # make sure this is disabled (only if we didn't reach the
  # dist-upgrade-to-lenny step in a previous iteration), so apache can
  # continue working during the rest of the upgrade
  dpkg -l untangle-apache2-config untangle-libuvm | grep '^ii.*6\.1\.' || rm -f /etc/apache2/sites-enabled/uvm /etc/apache2/mods-enabled/proxy_connect_untangle.load /usr/share/untangle/apache2/conf.d/*

  # install the newer postgres 7.4 from etch, as it follows the naming
  # convention in /etc/
  aptgetyes install --purge postgresql-7.4 postgresql-common postgresql postgresql-client-7.4 python-psycopg python libapache2-mod-python python-pycurl
  perl -i -pe 's/^port.+/port = 5432/' /etc/postgresql/7.4/main/postgresql.conf # force 5432

  aptgetyes dist-upgrade

  # free up some space
  apt-get clean
}

stepDistUpgradeToLenny() {
  stepName "stepDistUpgradeToLenny"

  # vanilla kernel-img.conf
  cat <<EOF >| /etc/kernel-img.conf
do_symlinks = yes
relative_links = yes
do_bootloader = no
do_bootfloppy = no
do_initrd = yes
link_in_boot = no
postinst_hook = update-grub
postrm_hook   = update-grub
EOF

  # exim4
  echo "dc_localdelivery='mail_spool'" >> /etc/exim4/update-exim4.conf.conf

  # dist-upgrade to lenny
  echo >| /etc/apt/sources.list
  echo >| /etc/apt/sources.list.d/untangle.list
  for distro in $UNTANGLE_61_DISTRIBUTIONS ; do
    echo "deb http://$(cat ${UNTANGLE_CREDENTIALS_FILE})@${UNTANGLE_MIRROR} $distro main premium upstream" >> /etc/apt/sources.list.d/untangle.list
  done
  aptgetupdate

  aptgetyes dist-upgrade
}

stepReinstallUntanglePackages() {
  stepName "stepReinstallUntanglePackages"

  # untangle packages from lenny
  [ -n "$UNTANGLE_PACKAGES" ] && aptgetyes install $UNTANGLE_PACKAGES libnfnetlink0

  # try to foce packages that are held back
  untangle_held_back=$(apt-get dist-upgrade -s | grep -A 1 -E '^The following packages have been kept back:$' | tail -1 | perl -pe 's/\s+/\n/g' | grep untangle | xargs)
  aptgetyes install $untangle_held_back

  held_back=$(apt-get dist-upgrade -s | grep -A 1 -E '^The following packages have been kept back:$' | tail -1 | perl -pe 's/\s+/\n/g' | xargs)
  aptgetyes install $held_back

  # restore ssh state
  [ "$START_SSHD" = 0 ] && update-rc.d ssh defaults

  # dist-upgrade again
  aptgetyes dist-upgrade || fail

  # restore SNMP settings
  cp -f ${SNMP_BACKUP} /etc/snmp/snmpd.conf

  # restore our LDAP database
  /etc/init.d/untangle-slapd stop
  rm -fr /var/lib/untangle-ldap
  mkdir /var/lib/untangle-ldap
  cp -f /usr/share/untangle-ldap-server/DB_CONFIG /var/lib/untangle-ldap/
  slapadd -c -f /etc/untangle-ldap/slapd.conf -l ${SLAPD_BACKUP}
  chown -R openldap:openldap /var/lib/untangle-ldap
  
  # re-enable reports
  for tid in $UNTANGLE_REPORTING_TIDS ; do
    ucli start $tid
  done

  # free up some space
  apt-get clean
}

stepFinish() {
  stepName "stepFinish"

  # install extra packages
  aptgetyes install $PACKAGES_TO_INSTALL

  # remove unnecessary packages
  removePackages $PACKAGES_TO_REMOVE

  # default sources.list
  cat >| /etc/apt/sources.list <<EOF
# Commented by Untangle: deb http://ftp.debian.org/debian lenny main contrib non-free

# Commented by Untangle: deb http://security.debian.org lenny/updates main contrib non-free

# Commented by Untangle: deb http://volatile.debian.org/debian-volatile lenny/volatile main contrib non-free

#deb http://www.backports.org/debian lenny-backports main contrib non-free
EOF

  # known update-alternatives bug
  ln -sf /usr/bin/vim.tiny /etc/alternatives/vi

  # motd
  ln -sf /var/run/motd /etc/motd

  # disable "tail -f upgrade"
  a2dissite default

  # locale settings
  perl -i -pe 's/.*en_US\.UTF-8/en_US.UTF-8/' /etc/locale.gen # uncomment it
  locale-gen # build it
  perl -i -pe 's/^(LC|LANG)/# $1/' /etc/environment
  echo LANG="en_US.UTF-8" >> /etc/environment # make it the default
  echo LC_ALL="en_US.UTF-8" >> /etc/environment # make it the default

  undo_divert

  echo >| /etc/apt/sources.list.d/untangle.list
  for distro in stable $UNTANGLE_61_DISTRIBUTIONS ; do
    echo "deb http://$(cat ${UNTANGLE_CREDENTIALS_FILE})@${UNTANGLE_MIRROR} $distro main premium upstream" >> /etc/apt/sources.list.d/untangle.list
  done
  aptgetupdate

  email "success"

  echo "#########################################"
  echo "All done, rebooting..."

  reboot
}

## main
date -Iseconds

case "$1" in
  -i)
    INTERACTIVE="true"
    echo "### Interactive mode ###"
    echo "### *foo*   --> step foo was run once."
    echo "### **foo** --> step foo was run twice."
    echo "### etc..." ;;
  -h)
    usage ;;
esac

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
