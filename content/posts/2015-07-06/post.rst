
.. Encrypting More: /boot Joins The Party
.. ======================================

Typically when installing major linux distros they make it easy to 
select encryption as an option to have encrypted block devices. 
This is great! The not so great part is the linux kernel and the initial 
ramdisk aren't typically invited to the party; they are left sitting in 
a separate and unencrypted ``/boot`` partition. Historically it has been 
necessary to leave ``/boot`` unencrypted because bootloaders
didn't support decrypting block devices. However, there are some dangers to leaving 
the bootloader and ramdisks unencrypted (see this_ post).

.. _this: https://twopointfouristan.wordpress.com/

Newer versions of ``GRUB`` do support booting from encrypted block devices
(a reference here_). This means that we can theoretically boot 
from a device that is encrypted. And the theory is right!

.. _here: http://michael-prokop.at/blog/2014/02/28/full-crypto-setup-with-grub2/

While the installers don't make it easy to actually install in this setup 
(without a separate boot partition) it is actually pretty easy to
convert an existing system to use this setup. I'll step through doing
this on a Fedora 22 system (I have done this one Fedora 21 in the past).

The typical disk configuration (with crypto selected) from a vanilla install 
of Fedora 22 looks like this::

    [root@localhost ~]# lsblk -i -o NAME,TYPE,MOUNTPOINT
    NAME                                          TYPE  MOUNTPOINT
    sda                                           disk  
    |-sda1                                        part  /boot
    `-sda2                                        part  
      `-luks-cb85c654-7561-48a3-9806-f8bbceaf3973 crypt 
        |-fedora-swap                             lvm   [SWAP]
        `-fedora-root                             lvm   /


What we need to do is copy the files from the ``/boot`` partition and 
into the ``/boot`` directory on the root filesystem. We can do this
easily with a bind mount like so::

    [root@localhost ~]# mount --bind / /mnt/
    [root@localhost ~]# cp -a /boot/* /mnt/boot/
    [root@localhost ~]# cp -a /boot/.vmlinuz-* /mnt/boot/
    [root@localhost ~]# diff -ur /boot/ /mnt/boot/
    [root@localhost ~]# umount /mnt 

This copied the files over and verified the contents matched. The
final step is to unmount the partition and to remove the mount from 
``/etc/fstab``. Since we'll no longer be using that partition we don't 
want kernel updates to be written to the wrong place::

    [root@localhost ~]# umount /boot
    [root@localhost ~]# sed -i -e '/\/boot/d' /etc/fstab

The next step is to write out a new ``grub.cfg`` that loads the
appropriate modules for loading from the encrypted disk::

    [root@localhost ~]# cp /boot/grub2/grub.cfg /boot/grub2/grub.cfg.backup
    [root@localhost ~]# grub2-mkconfig > /boot/grub2/grub.cfg
    Generating grub configuration file ...
    Found linux image: /boot/vmlinuz-4.0.4-301.fc22.x86_64
    Found initrd image: /boot/initramfs-4.0.4-301.fc22.x86_64.img
    Found linux image: /boot/vmlinuz-0-rescue-3f9d22f02d854d9a857066570127584a
    Found initrd image: /boot/initramfs-0-rescue-3f9d22f02d854d9a857066570127584a.img
    done
    [root@localhost ~]# cat /boot/grub2/grub.cfg | grep cryptodisk
            insmod cryptodisk
            insmod cryptodisk

And finally we need to reinstall the ``GRUB`` bootloader with 
``GRUB_ENABLE_CRYPTODISK=y`` set in ``/etc/default/grub``::

    [root@localhost ~]# echo GRUB_ENABLE_CRYPTODISK=y >> /etc/default/grub
    [root@localhost ~]# cat /etc/default/grub
    GRUB_TIMEOUT=5
    GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
    GRUB_DEFAULT=saved
    GRUB_DISABLE_SUBMENU=true
    GRUB_TERMINAL_OUTPUT="console"
    GRUB_CMDLINE_LINUX="rd.lvm.lv=fedora/swap rd.lvm.lv=fedora/root rd.luks.uuid=luks-cb85c654-7561-48a3-9806-f8bbceaf3973 rhgb quiet"
    GRUB_DISABLE_RECOVERY="true"
    GRUB_ENABLE_CRYPTODISK=y
    [root@localhost ~]# grub2-install /dev/sda 
    Installing for i386-pc platform.
    Installation finished. No error reported.


After a reboot you now get your grub prompt:

.. image:: http://dustymabe.com/content/2015-07-06/grubdecrypt.png


Unfortunately this does mean that you have to type your password twice on boot
but at least your system is more encrypted than it was before. This may not completely get
rid of the attack vector described in this_ post as there is still part of the
bootloader that isn't encrypted, but at least the grub stage2 and the kernel/ramdisk are
encrypted and should make it much harder to attack.

Happy Encrypting!

| Dusty
