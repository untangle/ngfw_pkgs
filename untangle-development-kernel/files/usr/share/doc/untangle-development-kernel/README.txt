Typical workflow:
=================

Let's define version="4.9.0-3-amd64".

1. build a disk image to be used in qemu:

     /usr/share/untangle-development-kernel/untangle-qemu-mkimage -f ~/images/stretch-untangle.qcow2 -a amd64 -r stretch

2. build a kernel your usual way, make sure you run modules_install, and
   remember where they are installed. This can typically be forced via:

     INSTALL_MOD_PATH=/tmp/modules-$version make modules_install

3. build an initrd using those modules (make sure the version you pass
   to -v is indeed the one matching the kernel you built):

     /usr/share/untangle-development-kernel/untangle-qemu-mkinitrd -f ~/images/dracut.initrd -p /tmp/modules-$version -v $version

4. update the modules tree in the qemu image (helper script to come later):

     mount -t ext4 -o loop,offset=$((2048*512)) ~/images/stretch-untangle.qcow2 /mnt
     rsync -aHvP --delete /tmp/modules-$version /mnt/lib/modules-$version
     umount /mnt

5. boot an instance, using the kernel and initrd produced earlier:

     /usr/share/untangle-development-kernel/untangle-qemu-run -f ~/images/stretch-untangle.qcow2 -k path/to/vmlinuz -i ~/images/dracut.initrd
