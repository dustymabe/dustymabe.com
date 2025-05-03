---
title: "Fedup 19 to 20 with a Thin LVM Configuration"
tags:
date: "2014-05-04"
draft: false
---

#### *Introduction*

\
I have been running my home desktop on thin logical volumes for a [while
now.](/2013/09/07/convert-an-existing-system-to-use-thin-lvs/) I have
enjoyed the flexibility of this setup and I like taking a snapshot
before making any big changes to my setup. Recently I decided to update
to Fedora 20 from Fedora 19 and I hit some trouble along the way because
the Fedora 20 initramfs (`images/pxeboot/upgrade.img`) that is used by
`fedup` for the upgrade does not have support for thin logical volumes.
After running `fedup` and rebooting you end up with a message to the
screen that looks something like this:\

```nohighlight
[  OK  ] Started Show Plymouth Boot Screen.
[  OK  ] Reached target Paths.
[  OK  ] Reached target Basic System.
[  191.023332] dracut-initqueue[363]: Warning: Could not boot.
[  191.028263] dracut-initqueue[363]: Warning: /dev/mapper/vg_root-thin_root does not exist
[  191.029689] dracut-initqueue[363]: Warning: /dev/vg_root/thin_root does not exist
         Starting Dracut Emergency Shell...
Warning: /dev/mapper/vg_root-thin_root does not exist
Warning: /dev/vg_root/thin_root does not exist

Generating "/run/initramfs/rdsosreport.txt"

Entering emergency mode. Exit the shell to continue.
```

#### *Working Around the Issue*

\
First off run install and run `fedup` :\

```nohighlight
[root@localhost ~]# yum update -y fedup fedora-release &>/dev/null
[root@localhost ~]# fedup --network 20                 &>/dev/null 
```

\
After running `fedup` usually you would be able to reboot and go
directly into the upgrade process. For us we need to add a few helper
utilities (thin\_dump, thin\_check, thin\_restore) to the initramfs so
that thin LVs will work. This can be done by appending more files in a
`cpio` archive to the end of the initramfs that was downloaded by
`fedup`. I learned about this technique by peeking at the
`initramfs_append_files()` function within fedup's
[boot.py.](https://github.com/wgwoods/fedup/blob/1e76a80b3149360ba14419cf2b215a679240a0ea/fedup/boot.py#L46)
Note also that I had to append a few libraries that are required by the
utilities into the initramfs as well.\
\

```nohighlight
[root@localhost ~]# cpio -co >> /boot/initramfs-fedup.img << EOF
/lib64/libexpat.so.1
/lib64/libexpat.so.1.6.0
/lib64/libstdc++.so.6
/lib64/libstdc++.so.6.0.18
/usr/sbin/thin_dump
/usr/sbin/thin_check
/usr/sbin/thin_restore
EOF
4334 blocks
[root@localhost ~]#
```

\
And thats it.. You are now able to reboot into the upgrade environment
and watch the upgrade. If you'd like to watch a (rather lengthy)
screencast of the entire process then you can download the
[screencast.log](/2014-05-04/screencast.log) and the
[screencast.timing](/2014-05-04/screencast.timing) files and follow the
instructions
[here.](/2012/01/11/create-a-screencast-of-a-terminal-session-using-scriptreplay/)\
\
Dusty
