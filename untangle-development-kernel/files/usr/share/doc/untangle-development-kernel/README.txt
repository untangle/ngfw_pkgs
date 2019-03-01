WARNING:
========

You need to install this package from an Untangle mirror: calling
files/usr/bin/ut-qemu-* from a git clone is unsupported, especially for
creating images.

To install on stretch, you can for instance do:

  echo deb http://package-server.untangle.int/public/stretch current main non-free | sudo tee /etc/apt/sources.list.d/stretch-current.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 735A9E18E8F62EDF413592460B9D6AE3627BF103
  sudo apt update
  sudo apt install untangle-development-kernel

A. Typical workflow:
====================

Let's define version="4.9.0-8-untangle-amd64".

1. Change your main interface to a bridge
-----------------------------------------

Most machines have a single interface (eth0 typically) that they use to connect to the network.
To make it easier for virtual machines to access the internet you need to change the main interface to a bridge interface.

Move your entire configuration to the bridge, and then move the original interface (eth0 for instance) to be a child of the bridge.
Now your server will be online in the same way but there will be a bridge for the virtual machines join to easily access the network/interface.

For example if your /etc/network/interfaces has:
# The primary network interface
allow-hotplug eth0
iface eth0 inet static
      address 172.16.2.80
      netmask 255.255.255.0
      gateway 172.16.2.1

change it to:
auto br0
iface br0 inet static
        address 172.16.2.80
        netmask 255.255.255.0
        gateway 172.16.2.1
	bridge_ports eth0

Then restart or restart networking with:
service networking restart

You will also need to add an "allow all" line in /etc/qemu/bridge.conf to make sure
that qemu has access to adding interfaces to bridges on your system.
Alternatively you can manually name only certain bridges like "allow br0".

2. build a UVM disk image
-------------------------

This only needs to be run once, when you start using the qemu
framework. In addition to the base Debian distribution (jessie or
stretch) specified via -r, you can also target a specific Untangle
distribution via -d; right now only "stable" (the default, what's on the
latest release-* branch) or "testing" (what's on the master branch) are
supported

  ut-qemu-mkimage -u -f ~/images/stretch-uvm.qcow2 -a amd64 -r stretch -d stable -a amd64

You can of course create additional images at any time, for instance to test a
new release.

3. build a kernel image and associated modules
----------------------------------------------

Simply build the kernel your usual way, and make sure you run
modules_install and remember where they are installed. This can
typically be forced via:

  # build and install modules
  INSTALL_MOD_PATH=~/images/modules-$version make bzImage modules modules_install

  # create symbols files
  depmod -b ~/images/modules-$version -a $version

For example I do something like this to build the traditional untangle kernel from git:
  upstream_version="4.9.30"
  cd ~/ngfw_kernels/debian-4.9.0
  make deps all
  cp -r ~/ngfw_kernels/debian-4.9.0/linux-4.9.30/debian/build/source_untangle ~/
  cp ~/ngfw_kernels/debian-4.9.0/linux-4.9.30/debian/build/build_amd64_untangle_amd64/.config ~/source_untangle/.config
  cd ~/source_untangle
  make -j32 bzImage
  make -j32 modules
  INSTALL_MOD_PATH=~/images/modules-$upstream_version make modules_install
  depmod -b ~/images/modules-$upstream_version -a $upstream_version
  cp ./arch/x86/boot/bzImage ~/images/

4. build an initrd suitable for qemu
------------------------------------

It will use those modules you just built, by using -p to point to the
directory they were installed in. Make extra sure the version you pass
to -v is indeed the one matching the kernel you built:

  ut-qemu-mkinitrd -f ~/images/dracut.initrd -p ~/images/modules-$version/lib/modules/$version -v $version

lsinitrd(1) can be used to inspect or unpack the created file if needed:

  lsinitrd ~/images/dracut.initrd
  lsinitrd --unpack ~/images/dracut.initrd

5. update the modules tree in the UVM disk image
------------------------------------------------

  ut-qemu-update-modules -f ~/images/stretch-uvm.qcow2 -p ~/images/modules-$version/lib/modules/$version -v $version

6. boot a UVM instance
----------------------

Two options are available, but in both you need to specify the bridge
interface on your host via -b, and also the name of the "local bridge"
(between uvm and client) via -c.

a. you use a kernel and initrd you built earlier
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You need to point to the kernel and initrd produced earlier; 

  ut-qemu-run -u -a amd64 -f ~/images/stretch-uvm.qcow2 -k ~/images/bzImage -i ~/images/dracut.initrd -b br0 -c br10

b. you are fine with the default Untangle kernel
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ut-qemu-run -u -a amd64 -f ~/images/stretch-uvm.qcow2 -b br0 -c br10

In both scenarios, this will spawn an SDL (graphical) window with your
qemu VM, and leave you with the QEMU monitor in the calling shell.

The monitor is awesome, with a wide array of debugging and introspection
capabilities (type "help" to list all commands). Quick example:

 ,----
 | (qemu) info network
 | hub 0                                            
 |  \ hub0port1: bridge.0: index=0,type=tap,helper=/usr/lib/qemu/qemu-bridge-helper,br=br.eth0
 |  \ hub0port0: e1000.0: index=0,type=nic,model=e1000,macaddr=52:54:00:12:34:56
 | (qemu) info block
 | hd0 (#block143): /home/seb/images/stretch-uvm.qcow2 (raw)
 |     Attached to:      /machine/peripheral/drive0/virtio-backend
 |     Cache mode:       writeback
 | [...]
 `----

At this point you can complete the setup wizard by accessing the
internal interface at https://192.168.2.1.

7. create a client disk image
-----------------------------

  ut-qemu-mkimage -f ~/images/stretch-client.qcow2

8. boot a client instance
-------------------------

No need to pass a kernel or initrd, this will automatically find grub
inside the disk image; you however want to specify the same "local
brige" you used to start the uvm instance, so that your client ends up
on the local side of your uvm:

  ut-qemu-run -f ~/images/stretch-client.qcow2 -b br10

If everything goes well, that client will grab a DHCP address from the
uvm, and then you're all set.
Make sure you specify that it join the "internal" bridge you specified
when launching the uvm.

B. Manage disk images
=====================

1. mount
--------

You can mount the qcow2 image, for instance to copy files or chroot
into:

  modprobe nbd max_parts=16
  qemu-nbd -c /dev/nbd0 ~/images/stretch-uvm.qcow2
  mount /dev/nbd0p1 /mnt
  [...]
  umount /mnt
  qemu-nbd -d /dev/nbd0

Make sure you umount before running a qemu instance based on that disk
image, otherwise you're guaranteed to encounter data corruption.

2. snapshots
------------

You can also create and restore snapshots on qcow2 images:

  # create a snapshot named "good-state"
  qemu-img snapshot -c good-state ~/images/image.qcow2

  # run a VM, potentially doing somethign dangerious in it
  ut-qemu-run [...] -f ~/images/image.qcow2 [...]

  # look at existing snapshots
  qemu-img info ~/images/image.qcow2

  # restore "good-state"
  qemu-img snapshot -a good-state ~/images/image.qcow2

C. Network setup:
=================

   (internet)
       |
       |
_________________
      eth0
uvm-bridge0 bridge
      tap0
_________________
       |
       |
_________________
  eth0 - DHCP
  untangle VM 
  eth1 - 192.168.2.1/24
_________________
       |
       |
_________________
   QEMU socket
_________________
       |
       |
_________________
  eth0 - DHCP
  stretch client
_________________
