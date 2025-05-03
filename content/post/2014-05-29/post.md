---
title: "Manual Linux Installs with Funky Storage Configurations"
tags:
date: "2014-05-29"
draft: false
---

#### *Introduction*

\
I often find that my tastes for hard drive configurations on my
installed systems is a bit outside of the norm. I like playing with
thin LVs, BTRFS snapshots, or whatever new thing
there is around the corner. The Anaconda UI has been adding support for
these fringe cases but I still find it hard to get Anaconda to do what I
want in certain cases.\
\
An example of this happened most recently when I went to reformat and
install Fedora 20 on my laptop. Ultimately what I wanted was encrypted
root and swap devices and btrfs filesystems on root and boot. One other
requirement was that I needed to leave sda4 (a Windows Partition)
completely intact. At the end the configuration should look something
like:\
\

```nohighlight
[root@lintop ~]# lsblk /dev/sda
NAME           MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
sda              8:0    0 465.8G  0 disk
├─sda1           8:1    0     1G  0 part  /boot
├─sda2           8:2    0     4G  0 part
│ └─cryptoswap 253:1    0     4G  0 crypt [SWAP]
├─sda3           8:3    0 299.2G  0 part
│ └─cryptoroot 253:0    0 299.2G  0 crypt /
└─sda4           8:4    0 161.6G  0 part
```

\
After a few failed attempts with Anaconda I decided to do a custom
install instead.

#### *Custom Install*

\
I used the Fedora 20 install DVD (and thus the Anaconda environment) to
do the install but I performed all the steps manually by switching to a
different terminal with a prompt. First off I used `fdisk` to format the
disk the way I wanted. The results looked like:

```nohighlight
[anaconda root@localhost ~]# fdisk -l /dev/sda

Disk /dev/sda: 465.8 GiB, 500107862016 bytes, 976773168 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: dos
Disk identifier: 0xcfe1cf72

Device    Boot     Start       End    Blocks  Id System
/dev/sda1 *         2048   2099199   1048576  83 Linux
/dev/sda2        2099200  10487807   4194304  82 Linux swap / Solaris
/dev/sda3       10487808 637945855 313729024  83 Linux
/dev/sda4      637945856 976773119 169413632   7 HPFS/NTFS/exFAT
```

\
Next I set up the encrypted root (`/dev/sda3`) device and created a
btrfs filesystems on both boot (`/dev/sda2`) and the encrypted root
device (`/dev/mapper/cryptoroot`):\
\

```nohighlight
[anaconda root@localhost ~]# cryptsetup luksFormat /dev/sda3
...
[anaconda root@localhost ~]# cryptsetup luksOpen /dev/sda3 cryptoroot
Enter passphrase for /dev/sda3:
[anaconda root@localhost ~]#
[anaconda root@localhost ~]# mkfs.btrfs --force --label=root /dev/mapper/cryptoroot
...
fs created label root on /dev/mapper/cryptoroot
...
[anaconda root@localhost ~]# mkfs.btrfs --force --label=boot --mixed /dev/sda1
...
fs created label boot on /dev/sda1
...
```

\
Next, if you want to use the `yum` cli then you need to install it
because some of the files are left out of the environment by default. I
show the error you get below and then how to fix it:\
\

```nohighlight
[anaconda root@localhost ~]# yum list
Traceback (most recent call last):
  File "/bin/yum", line 28, in <module>
    import yummain
ImportError: No module named yummain
[anaconda root@localhost ~]# rpm -ivh --nodeps /run/install/repo/Packages/y/yum-3.4.3-106.fc20.noarch.rpm
...
```

\
I needed to set up a repo that used the DVD as the source:\
\

```nohighlight
[anaconda root@localhost ~]# cat <<EOF > /etc/yum.repos.d/repo.repo
[dvd]
name=dvd
baseurl=file:///run/install/repo
enabled=1
gpgcheck=0
EOF
```

\
Now I could mount my root device on `/mnt/sysimage` and then lay down
the basic filesystem tree by installing the `filesystem` package into
it:\
\

```nohighlight
[anaconda root@localhost ~]# mount /dev/mapper/cryptoroot /mnt/sysimage/
[anaconda root@localhost ~]# yum install -y --installroot=/mnt/sysimage filesystem
...
Complete!
```

\
Now I can mount boot and other filesystems into the `/mnt/sysimage`
tree:\
\

```nohighlight
[anaconda root@localhost ~]# mount /dev/sda1 /mnt/sysimage/boot/
[anaconda root@localhost ~]# mount -v -o bind /dev /mnt/sysimage/dev/
mount: /dev bound on /mnt/sysimage/dev.
[anaconda root@localhost ~]# mount -v -o bind /run /mnt/sysimage/run/
mount: /run bound on /mnt/sysimage/run.
[anaconda root@localhost ~]# mount -v -t proc proc /mnt/sysimage/proc/
mount: proc mounted on /mnt/sysimage/proc.
[anaconda root@localhost ~]# mount -v -t sysfs sys /mnt/sysimage/sys/
mount: sys mounted on /mnt/sysimage/sys.
```

\
Now ready for the actual install. For this install I just went with a
small set of packages (I'll use yum once the system is up to add on what
I want later).\
\

```nohighlight
[anaconda root@localhost ~]# yum install -y --installroot=/mnt/sysimage \
                                @core @standard kernel grub2 grub2-tools btrfs-progs
...
Complete!
```

\
After the install there are a few housekeeping items to take care of. I
started with populating `crypttab`, populating `fstab`, changing the
root password, and touching `/.autorelabel` to trigger an selinux
relabel on first boot:\
\

```nohighlight
[anaconda root@localhost ~]# chroot /mnt/sysimage/
[anaconda root@localhost /]# cat <<EOF > /etc/crypttab
cryptoswap  /dev/sda2   /dev/urandom    swap
cryptoroot  /dev/sda3   -
EOF
[anaconda root@localhost /]# cat <<EOF > /etc/fstab
LABEL=boot             /boot  btrfs    defaults        1 2
/dev/mapper/cryptoswap swap   swap     defaults        0 0
/dev/mapper/cryptoroot /      btrfs    defaults        1 1
EOF
[anaconda root@localhost /]# passwd --stdin root <<< "password"
Changing password for user root.
passwd: all authentication tokens updated successfully.
[anaconda root@localhost /]# touch /.autorelabel
```

\
Next I needed to install grub and make a config file. I set the grub
kernel command line arguments and then generated a config. The config
needed some fixing up (I am not using EFI on my system, but
`grub2-mkconfig` thought I was because I had booted through EFI off of
the install CD).\
\

```nohighlight
[anaconda root@localhost /]# echo 'GRUB_CMDLINE_LINUX="ro root=/dev/mapper/cryptoroot"' > /etc/default/grub
[anaconda root@localhost /]# grub2-mkconfig -o /boot/grub2/grub.cfg 
Generating grub.cfg ...
Found linux image: /boot/vmlinuz-3.11.10-301.fc20.x86_64
Found initrd image: /boot/initramfs-3.11.10-301.fc20.x86_64.img
Found linux image: /boot/vmlinuz-0-rescue-81c04e9030594ef6a5265a95f58ccf98
Found initrd image: /boot/initramfs-0-rescue-81c04e9030594ef6a5265a95f58ccf98.img
done
[anaconda root@localhost /]# sed -i s/linuxefi/linux/ /boot/grub2/grub.cfg
[anaconda root@localhost /]# sed -i s/initrdefi/initrd/ /boot/grub2/grub.cfg
[anaconda root@localhost /]# grub2-install -d /usr/lib/grub/i386-pc/ /dev/sda
Installation finished. No error reported.
```

\
**NOTE:** `grub2-mkconfig` didn't find my windows partition until I
rebooted into the system and ran it again.\
\
Finally I re-executed `dracut` to pick up the crypttab, exited the
chroot, unmounted the filesystems, and rebooted into my new system:\

```nohighlight
[anaconda root@localhost /]# dracut --kver 3.11.10-301.fc20.x86_64 --force
[anaconda root@localhost /]# exit
[anaconda root@localhost ~]# umount /mnt/sysimage/{boot,dev,run,sys,proc}
[anaconda root@localhost ~]# reboot
```

\
After booting into Fedora I was then able to run grub2-mkconfig again
and get it to recognize my (untouched) Windows partition:\
\

```nohighlight
[root@localhost /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub.cfg ...
Found linux image: /boot/vmlinuz-3.11.10-301.fc20.x86_64
Found initrd image: /boot/initramfs-3.11.10-301.fc20.x86_64.img
Found linux image: /boot/vmlinuz-0-rescue-375c7019484a45838666c572d241249a
Found initrd image: /boot/initramfs-0-rescue-375c7019484a45838666c572d241249a.img
Found Windows 7 (loader) on /dev/sda4
done
```

\
And that's pretty much it. Using this method you can have virtually any
hard drive setup that you desire. Hope someone else can find this
useful.\
\
Dusty\
\
***P.S.*** You can start sshd in anaconda by running
`systemctl start anaconda-sshd.service`.
