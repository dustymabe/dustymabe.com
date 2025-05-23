---
title: "Booting Anaconda from Software RAID1 Device"
tags:
date: "2013-05-05"
draft: false
---

Sometimes you just want to boot Anaconda from a software raid device
that houses both the stage1 (initrd.img) and stage2 (install.img)
images. There are various reasons to do this some of which include:

-   Booting Anaconda into rescue mode from hard drive (RAID 1)
-   Installing directly from hard drive (RAID 1)
-   Running
    [PreUpgrade](http://fedoraproject.org/wiki/Features/PreUpgrade) (Now
    Deprecated)

Running Anaconda from a RAID 1 device is unsupported at least up until
the rhel 6.4 version of Anaconda and is documented in BZ
[#500004](https://bugzilla.redhat.com/show_bug.cgi?id=500004) (note
that this is a "feature", not a bug) . It may be supported now with the
new [Anaconda
redesign](https://ohjeezlinux.wordpress.com/2013/02/05/anaconda-retrospective/)
, but I havn't put in the time to find out yet.\
\
That being said, a good workaround mentioned in the comments of the bug
report is to simply attach an install cd that contains the same version
of Anaconda you are trying to boot and it will automatically find it and
continue on. However, if you often need to boot Anaconda like this it
can be tedious and there is another way that may be more desireable to
some.\
\
Since /boot/ is set up on a software [RAID
1](http://en.wikipedia.org/wiki/Standard_RAID_levels#RAID_1) each member
device contains an exact copy of what is on the RAID device. This means
that you can directly mount any of the member devices as long as you
specify the filesystem type. This is exactly where Anaconda has a
problem.\
\
The kernel and stage1 are loaded by grub, which sucessfully ignores the
fact that the device is a part of a raid and just treats it like an ext
filesystem. Anaconda on the other hand attempts to mount the specified
device to find the stage2 image. In doing this Anaconda calls
`/bin/mount` and specifies an fs type of *auto* ( ` -t auto` ). Since
the device has an MD superblock, mount fails to detect it is ext4 and
does not mount the device.\
\
What is the solution for this?? Well, we need to get rid of the
superblock :)\
\
As a brief example I will show how to set up Anaconda to boot into
rescue mode from a software RAID 1. First we need to copy the kernel,
stage1, and stage2 images from an install cd and into the /boot/
filesystem.\
\

```nohighlight
[root@cent64 ~]# mkdir /mnt/dusty
[root@cent64 ~]# mount /dev/sr0 /mnt/dusty/
mount: block device /dev/sr0 is write-protected, mounting read-only
[root@cent64 ~]#
[root@cent64 ~]# mkdir /boot/images
[root@cent64 ~]# cp /mnt/dusty/images/install.img /boot/images/
[root@cent64 ~]# cp /mnt/dusty/isolinux/initrd.img /boot/
[root@cent64 ~]# cp /mnt/dusty/isolinux/vmlinuz /boot/
```

\
Next, add a new entry into the grub.conf so that we can choose to boot
into the Anaconda rescue environment. The new entry is shown below. Note
that I am specifying where to find the stage2 image from the kernel
command line.\
\

```nohighlight
title rescue
        root (hd0,0)
        kernel /vmlinuz rescue stage2=hd:sda1:/
        initrd /initrd.img

```

\
Now we must zero out the superblock on /dev/sda1 which will enable
Anaconda's mount to auto detect the ext4 fs on sda1.\
\

```nohighlight
[root@cent64 ~]# umount /boot
[root@cent64 ~]# mdadm --stop /dev/md0
mdadm: stopped /dev/md0
[root@cent64 ~]# mdadm --zero-superblock /dev/sda1
[root@cent64 ~]#
[root@cent64 ~]# mdadm --examine /dev/sda1
mdadm: No md superblock detected on /dev/sda1.
```

\
After rebooting and manually selecting "rescue" at the grub screen I am
able to successfully boot into rescue mode using Anaconda!!!\
\
Taking a peak at the program.log from Anaconda shows me exactly what
command was run to mount the device.\
\

```nohighlight
Running... /bin/mount -n -t auto -o ro /dev/sda1 /mnt/isodir
```

\
Now we achieved what we wanted but the fun isn't all over.. After doing
this you must fix the superblock on sda1. After boot you can see that
sda1 is not being mirrored.\
\

```nohighlight
[root@cent64 ~]# cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sdb1[1]
      409536 blocks super 1.0 [2/1] [_U]

md1 : active raid1 sda2[0] sdb2[1]
      20544384 blocks super 1.1 [2/2] [UU]
      bitmap: 0/1 pages [0KB], 65536KB chunk

unused devices: <none>
```

\
You can add it back into the array like so. Once it is done syncing it
is good as new again:\
\

```nohighlight
[root@cent64 ~]# mdadm --add /dev/md0 /dev/sda1
mdadm: added /dev/sda1
[root@cent64 ~]#
[root@cent64 ~]# cat /proc/mdstat
Personalities : [raid1]
md0 : active raid1 sda1[2] sdb1[1]
      409536 blocks super 1.0 [2/1] [_U]
      [==>..................]  recovery = 11.0% (45248/409536) finish=0.2min speed=22624K/sec

md1 : active raid1 sda2[0] sdb2[1]
      20544384 blocks super 1.1 [2/2] [UU]
      bitmap: 1/1 pages [4KB], 65536KB chunk

[root@cent64 ~]#
[root@cent64 ~]# mdadm --examine /dev/sda1
/dev/sda1:
          Magic : a92b4efc
        Version : 1.0
    Feature Map : 0x0
     Array UUID : d23c9678:2918b450:86f94f62:1a38d114
           Name : cent64:0  (local to host cent64)
  Creation Time : Sun May  5 14:40:41 2013
     Raid Level : raid1
   Raid Devices : 2

 Avail Dev Size : 819176 (400.06 MiB 419.42 MB)
     Array Size : 409536 (400.00 MiB 419.36 MB)
  Used Dev Size : 819072 (400.00 MiB 419.36 MB)
   Super Offset : 819184 sectors
          State : clean
    Device UUID : 805e3791:be06e475:619ee8c0:4e2599f4

    Update Time : Sun May  5 15:31:00 2013
       Checksum : edd172ef - correct
         Events : 19


   Device Role : Active device 0
   Array State : AA ('A' == active, '.' == missing)
[root@cent64 ~]#
```

\
\
**NOTE:** As a quick note before I part I would like to stress the fact
that the steps taken in the example above may not satisfy all needs.
Please understand what you are doing before you do it. As in all cases,
backups are your friend.\
\
Until Next Time..\
\
Dusty
