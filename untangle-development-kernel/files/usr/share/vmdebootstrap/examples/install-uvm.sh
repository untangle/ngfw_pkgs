#! /bin/bash

CHROOT=$1
IMAGE=$2

APT_OPTIONS="--allow-unauthenticated -o DPkg::Options::=--force-confnew --yes --force-yes"

# disable starting of services
echo exit 101 > ${CHROOT}/usr/sbin/policy-rc.d
chmod +x ${CHROOT}/usr/sbin/policy-rc.d

# mount required PFS
for pfs in dev dev/pts proc sys ; do
  mount --bind /$pfs ${CHROOT}/$pfs
done

# install top-level packages
chroot $CHROOT bash -c "DEBIAN_FRONTEND=noninteractive apt-get install $APT_OPTIONS untangle-gateway untangle-linux-config untangle-client-local untangle-extra-utils"

# umount PFS
for pfs in sys proc dev/pts dev ; do
  umount -l ${CHROOT}/$pfs || true
done

# re-enable starting of services
rm ${CHROOT}/usr/sbin/policy-rc.d

# force vda1 in /etc/fstab
perl -i -pe 's|.*\s/\s|/dev/vda1 / |' /etc/fstab

# on jessie & stretch, the initrd produced by dracut causes systemd to
# choke during the switch-root service startup, for no apparent
# reason.
# This does not happen with the more recent systemd version in
# buster.
version=$(systemd --version | awk '/^systemd / { print $2 }')
if [[ $version -lt 236 ]] ; then 
  sed -i -e '/^OnFailure=/d' ${CHROOT}/lib/systemd/system/initrd-switch-root.service
fi

exit 0
