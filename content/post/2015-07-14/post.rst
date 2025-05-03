---
title: "Fedora BTRFS+Snapper PART 1: System Preparation"
tags:
date: "2015-07-14"
draft: false
url: "/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/"
---

.. Fedora BTRFS+Snapper PART 1: System Preparation
.. ===============================================

The Problem
-----------

For some time now I have wanted a linux desktop setup where I could
run updates automatically and not worry about losing productivity if
my system gets hosed from the update. My desired setup to achieve
this has been a combination of ``snapper`` and ``BTRFS``, but
unfortunately the support on Fedora for full rollback isn't
quite there.

In Fedora 22 the support for rollback was added but there
is one final piece of the puzzle that is missing that I need in order
to have a fully working setup: I needed GRUB to respect the *default subvolume* 
that is set on the ``BTRFS`` filesystem. In the past ``GRUB`` did use the default
subvolume but this behavior was removed in ``82591fa`` (link_).

.. _link: http://git.savannah.gnu.org/cgit/grub.git/commit/?id=82591fa6e7941efe2723a23cb1d924dfe0641974

With ``GRUB`` respecting the default subvolume I can include ``/boot/``
just as a directory on my system (not as a separate subvolume) and it
will be included in all of the snapshots that are created by ``snapper``
of the root filesystem. 

In order to get this functionality I grabbed some of the patches from
the SUSE guys and applied them to the Fedora ``GRUB`` rpm. All of the
work and the resulting rpms can be found here_. 

.. _here: https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume

System Preparation
------------------

So now I had a ``GRUB`` rpm that would work for me. The first step is to
get my system up and running in a setup that I could then use snapper
on top of. I mentioned before that I wanted to put ``/boot/`` just as a
directory on the ``BTRFS`` filesystem. I also wanted it to be encrypted
as I have done in the past_.

.. _past: /2015/07/06/encrypting-more-boot-joins-the-party/

This means I have yet another setup that is funky_ and I'll need to
basically install it from scratch using Anaconda and a chroot
environment.

.. _funky: /2014/05/29/manual-linux-installs-with-funky-storage-configurations/

After getting up and running in anaconda I then switched to a
different virtual terminal and formatted my hard disk, set up an
encrypted ``LUKS`` device, created a ``VG`` and two ``LVs``, and finally a
``BTRFS`` filesystem::

    [anaconda root@localhost ~]# fdisk /dev/sda <<EOF
    o
    n
    p
    1
    2048

    w
    EOF
    [anaconda root@localhost ~]# lsblk /dev/sda
    NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
    sda      8:0    0 465.8G  0 disk 
    `-sda1   8:1    0 465.8G  0 part
    [anaconda root@localhost ~]# cryptsetup luksFormat /dev/sda1           
    [anaconda root@localhost ~]# cryptsetup luksOpen /dev/sda1 cryptodisk
    [anaconda root@localhost ~]# vgcreate vgroot /dev/mapper/cryptodisk
    [anaconda root@localhost ~]# lvcreate --size=4G --name lvswap vgroot
    [anaconda root@localhost ~]# mkswap /dev/vgroot/lvswap
    [anaconda root@localhost ~]# lvcreate -l 100%FREE --name lvroot vgroot
    [anaconda root@localhost ~]# mkfs.btrfs /dev/vgroot/lvroot

*NOTE:* Most of the commands run above have truncated output for brevity.

The next step was to mount the filesystem and install software
into the filesystem in a chrooted environment. Since the ``dnf``
binary isn't actually installed in the anaconda environment by
default we first need to install it::


    [anaconda root@localhost ~]# rpm -ivh --nodeps /run/install/repo/Packages/d/dnf-1.0.0-1.fc22.noarch.rpm
    warning: /run/install/repo/Packages/d/dnf-1.0.0-1.fc22.noarch.rpm: Header V3 RSA/SHA256 Signature, key ID 8e1431d5: NOKEY
    Preparing...                          ################################# [100%]
    Updating / installing...
       1:dnf-1.0.0-1.fc22                 ################################# [100%]

Now we can *"create"* a repo file from the repo that is on the media
and install the bare minimum (the ``filesystem`` rpm)::

    [anaconda root@localhost ~]# mount /dev/vgroot/lvroot /mnt/sysimage/
    [anaconda root@localhost ~]# mkdir /etc/yum.repos.d
    [anaconda root@localhost ~]# cat <<EOF > /etc/yum.repos.d/dvd.repo
    [dvd]
    name=dvd
    baseurl=file:///run/install/repo
    enabled=1
    gpgcheck=0
    EOF
    [anaconda root@localhost ~]# dnf install -y --releasever=22 --installroot=/mnt/sysimage filesystem
    ...
    Complete!

The reason we only installed the ``filesystem`` rpm is because a lot of
the other rpms we are going to install will fail if some of the
*"special"* directories aren't mounted. We'll go ahead and mount them
now::

    [anaconda root@localhost ~]# mount -v -o bind /dev /mnt/sysimage/dev/
    mount: /dev bound on /mnt/sysimage/dev.
    [anaconda root@localhost ~]# mount -v -o bind /run /mnt/sysimage/run/
    mount: /run bound on /mnt/sysimage/run.
    [anaconda root@localhost ~]# mount -v -t proc proc /mnt/sysimage/proc/ 
    mount: proc mounted on /mnt/sysimage/proc.
    [anaconda root@localhost ~]# mount -v -t sysfs sys /mnt/sysimage/sys/
    mount: sys mounted on /mnt/sysimage/sys.


Now we can install the rest of the software into the chroot
environment::

    [anaconda root@localhost ~]# cp /etc/yum.repos.d/dvd.repo /mnt/sysimage/etc/yum.repos.d/
    [anaconda root@localhost ~]# dnf install -y --installroot=/mnt/sysimage --disablerepo=* --enablerepo=dvd @core @standard kernel btrfs-progs lvm2
    ...
    Complete!

We can also install the *"special"* ``GRUB`` packages that I created and
then get rid of the repo file because we won't need it any longer::

    [anaconda root@localhost ~]# dnf install -y --installroot=/mnt/sysimage --disablerepo=* --enablerepo=dvd \
    https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume/raw/master/rpmbuild/RPMS/x86_64/grub2-2.02-0.16.fc22.dusty.x86_64.rpm \
    https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume/raw/master/rpmbuild/RPMS/x86_64/grub2-tools-2.02-0.16.fc22.dusty.x86_64.rpm
    ...
    Complete!
    [anaconda root@localhost ~]# rm /mnt/sysimage/etc/yum.repos.d/dvd.repo

Now we can do some minimal system configuration by chrooting into the
system and setting up ``crypttab``, setting up ``fstab``, setting the root
password and setting up the system to a relabel on boot::

    [anaconda root@localhost ~]# chroot /mnt/sysimage
    [anaconda root@localhost /]# ls -l /dev/disk/by-uuid/f0d889d8-5225-4d9d-9a89-edd387e65ab7 
    lrwxrwxrwx. 1 root root 10 Jul 14 02:24 /dev/disk/by-uuid/f0d889d8-5225-4d9d-9a89-edd387e65ab7 -> ../../sda1
    [anaconda root@localhost /]# cat <<EOF > /etc/crypttab
    cryptodisk /dev/disk/by-uuid/f0d889d8-5225-4d9d-9a89-edd387e65ab7 -
    EOF
    [anaconda root@localhost /]# cat <<EOF > /etc/fstab
    /dev/vgroot/lvroot / btrfs defaults 1 1
    /dev/vgroot/lvswap swap swap defaults 0 0
    EOF
    [anaconda root@localhost /]# passwd --stdin root <<< "password"
    Changing password for user root.
    passwd: all authentication tokens updated successfully.
    [anaconda root@localhost /]# touch /.autorelabel

Finally configure and install ``GRUB`` on ``sda`` and generate a ramdisk
that has all the required modules using ``dracut``::

    [anaconda root@localhost /]# echo GRUB_ENABLE_CRYPTODISK=y >> /etc/default/grub
    [anaconda root@localhost /]# echo SUSE_BTRFS_SNAPSHOT_BOOTING=true >> /etc/default/grub
    [anaconda root@localhost /]# grub2-mkconfig -o /boot/grub2/grub.cfg
    Generating grub configuration file ...
    File descriptor 4 (/) leaked on vgs invocation. Parent PID 29465: /usr/sbin/grub2-probe
    File descriptor 4 (/) leaked on vgs invocation. Parent PID 29465: /usr/sbin/grub2-probe
    Found linux image: /boot/vmlinuz-4.0.4-301.fc22.x86_64
    Found initrd image: /boot/initramfs-4.0.4-301.fc22.x86_64.img
    Found linux image: /boot/vmlinuz-0-rescue-225efda374c043e3886d349ef724c79e
    Found initrd image: /boot/initramfs-0-rescue-225efda374c043e3886d349ef724c79e.img
    done
    [anaconda root@localhost /]# grub2-install /dev/sda
    Installing for i386-pc platform.
    File descriptor 4 (/) leaked on vgs invocation. Parent PID 29866: grub2-install
    File descriptor 4 (/) leaked on vgs invocation. Parent PID 29866: grub2-install
    File descriptor 4 (/) leaked on vgs invocation. Parent PID 29866: grub2-install
    File descriptor 7 (/) leaked on vgs invocation. Parent PID 29866: grub2-install
    File descriptor 8 (/) leaked on vgs invocation. Parent PID 29866: grub2-install
    Installation finished. No error reported.
    [anaconda root@localhost /]# dracut --kver 4.0.4-301.fc22.x86_64 --force


Now we can exit the chroot, unmount all filesystems and reboot into
our new system::

    [anaconda root@localhost /]# exit
    exit
    [anaconda root@localhost ~]# umount /mnt/sysimage/{dev,run,sys,proc}
    [anaconda root@localhost ~]# umount /mnt/sysimage/
    [anaconda root@localhost ~]# reboot


To Be Continued
---------------

So we have set up the system to have a single ``BTRFS`` filesystem (no
subvolumes) on top of ``LVM`` on top of ``LUKS`` and with a custom ``GRUB``
that respects the configured default subvolume on the ``BTRFS``
filesystem. Here is what an ``lsblk`` shows::

    [root@localhost ~]# lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT /dev/sda
    NAME                TYPE  FSTYPE      MOUNTPOINT
    sda                 disk              
    `-sda1              part  crypto_LUKS 
      `-cryptodisk      crypt LVM2_member 
        |-vgroot-lvswap lvm   swap        [SWAP]
        `-vgroot-lvroot lvm   btrfs       /

In a later post I will configure ``snapper`` on this system
and show how rollbacks can be used to simply revert changes that have
been made.

| Dusty
