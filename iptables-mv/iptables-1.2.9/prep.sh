#!/bin/sh 

set -e

iptables="iptables-1.2.9"
kernel="linux-2.4.19"
patch_o_matic="patch-o-matic-20030912"

pwd=$(pwd)
upstream="${pwd}/upstream"
build="${pwd}/debian/build"
doc="${build}/doc"
stamp="${build}/stamp"
patches="${pwd}/patches"

kernel_src="${build}/${kernel}"
patch_o_matic_src="${build}/${patch_o_matic}"

unpack() {
  for tarball in ${@}; do
    dinfo "$(basename $tarball).tar.bz2"
    bunzip2 -dc ${upstream}/${tarball}.tar.bz2 | ( cd debian/build; tar xf -; )
  done
}

sgml() {
  for sgmldoc in ${@}; do
    dinfo "${sgmldoc}-HOWTO.sgml"
    sgml2html ${upstream}/${sgmldoc}-HOWTO.sgml >/dev/null 2>&1
  done
}

dinfo () {
  echo "${0} - $*"
}

# package build path
install -d ${doc} ${stamp}

# unpack upstream tarballs
dinfo "unarchiving upstream source..."
unpack linux-2.4.19 
unpack linux-2.4.23
unpack ${iptables} 
unpack ${patch_o_matic}

# process sgml HOWTOS
dinfo "processing sgml documents..."
( cd ${doc}; sgml packet-filtering NAT netfilter-hacking netfilter-extensions )

# compile upstream changelog
dinfo "assembling changelog..."
> ${doc}/changelog
for i in $(cd ${upstream}; ls changes*txt| sort -r); do
  dinfo "$i"
  cat ${upstream}/$i >>  ${doc}/changelog
done
for i in $(cd ${upstream}; ls changes*html| sort -r); do
  dinfo "$i"
  html2text -o - ${upstream}/$i >> ${doc}/changelog
done

# patch-o-matic patches
dinfo "applying patch-o-matic patches..."
for patch in $(cat patch-o-matic.accepted.list); do
  dinfo "$(basename $patch)"
  patch -p1 -s -f -d ${kernel_src} < ${pwd}/${patch}
done

# local debian patches
dinfo "applying local debian patches..."
for patch in $(cd ${patches}; ls *.patch); do
  dinfo "$patch"
  patch -p1 -s -d debian < ${patches}/${patch}
done

# remove libulog header
rm -r ${build}/${iptables}/include/libipulog
