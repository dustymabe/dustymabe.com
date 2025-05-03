---
title: "Mounting a Partition Within a Disk Image"
tags:
date: "2012-12-15"
draft: false
---

[Last time](/2012/11/15/create-a-disk-image-without-enough-free-space/)
I walked through creating a sparse disk image using `dd` and
`cp --sparse=always`. OK, we have a disk image. Now what?\
\
Normally it would suffice to just set up a loop device and then mount,
but this disk image doesn't just contain a filesystem. It has 4
partitions each with their own filesystem. This means in order to mount
one of the filesystems we have to take a few extra steps.\
\
There is an easy and a hard way to do this. I'll start with the hard
way..\

#### *The Hard Way*

\
To manually mount a particular partition on the disk we need to find a
little information about where the partition is located on the disk. We
need to use `fdisk` to find the offsets of the start and end of the
partition.\
\

```nohighlight
dustymabe@media: mnt>sudo fdisk -l /mnt/lenovo.img

Disk /mnt/lenovo.img: 500.1 GB, 500107862016 bytes
255 heads, 63 sectors/track, 60801 cylinders, total 976773168 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0xf82e2761

          Device Boot      Start         End      Blocks   Id  System
/mnt/lenovo.img1   *        2048      411647      204800    7  HPFS/NTFS/exFAT
/mnt/lenovo.img2          411648   884611071   442099712    7  HPFS/NTFS/exFAT
/mnt/lenovo.img3       884611072   946051071    30720000    7  HPFS/NTFS/exFAT
/mnt/lenovo.img4       946051072   976361471    15155200   12  Compaq diagnostics
```

\
From the `fdisk` output we can see that the second partition starts at
411648 sectors times 512 bytes (210763776 bytes) into the disk image. We
can also see that the partition ends at 884611071 sectors times 512
bytes (452920868352 bytes). This means that the size of the partition is
452920868352 - 210763776 = 452710104576 bytes.\
\
We can use this information to set up a loop device using `losetup` like
so:\
\

```nohighlight
dustymabe@media: >sudo losetup -v -f -o 210763776 --sizelimit 452710104576 /mnt/lenovo.img
dustymabe@media: >
dustymabe@media: >losetup -a
/dev/loop0: []: (/mnt/lenovo.img), offset 210763776, sizelimit 452710104576
dustymabe@media: >
dustymabe@media: >sudo blkid /dev/loop0
/dev/loop0: LABEL="Windows7_OS" UUID="7C64B5C764B58504" TYPE="ntfs"
```

\
Finally, the loop device can be mounted just like a normal block
device:\
\

```nohighlight
dustymabe@media: >sudo mount -o ro /dev/loop0 ~/Desktop/mount/
dustymabe@media: >ls ~/Desktop/mount/Users
All Users  Default  Default User  desktop.ini  dustymabe  Public
```

\

#### *The Easy Way*

\
You can use `partx` to probe a disk image and detect all partitions. You
can also have `partx` tell the kernel about all partitions and add
devices for each partition. An example of this is shown below:\
\

```nohighlight
dustymabe@media: >sudo losetup -v -f /mnt/lenovo.img
dustymabe@media: >sudo losetup -a
/dev/loop0: [2145]:12 (/mnt/lenovo.img)
dustymabe@media: >
dustymabe@media: >sudo partx --show /dev/loop0
[sudo] password for dustymabe:
NR     START       END   SECTORS   SIZE NAME UUID
 1      2048    411647    409600   200M
 2    411648 884611071 884199424 421.6G
 3 884611072 946051071  61440000  29.3G
 4 946051072 976361471  30310400  14.5G
dustymabe@media: >
dustymabe@media: >sudo partx -v --add /dev/loop0
partition: none, disk: /dev/loop0, lower: 0, upper: 0
/dev/loop0: partition table type 'dos' detected
/dev/loop0: partition #1 added
/dev/loop0: partition #2 added
/dev/loop0: partition #3 added
/dev/loop0: partition #4 added
dustymabe@media: >
dustymabe@media: >
dustymabe@media: >sudo blkid /dev/loop0*
/dev/loop0p1: LABEL="SYSTEM_DRV" UUID="0840B6DE40B6D224" TYPE="ntfs"
/dev/loop0p2: LABEL="Windows7_OS" UUID="7C64B5C764B58504" TYPE="ntfs"
/dev/loop0p3: LABEL="LENOVO" UUID="7652C00A52BFCCDD" TYPE="ntfs"
/dev/loop0p4: LABEL="LENOVO_PART" UUID="983479C03479A244" TYPE="ntfs"
```

\
Now you can directly mount `/dev/loop0p2` just as we did before.\
\

```nohighlight
dustymabe@media: >sudo mount -o ro /dev/loop0p2 ~/Desktop/mount/
dustymabe@media: >ls ~/Desktop/mount/Users/
All Users  Default  Default User  desktop.ini  dustymabe  Public
dustymabe@media: >
```

\
There ya go.. Two ways to mount partitions within a disk image. If I get
a chance I'll go over a third using some free tools from the *virt*
community.\
Dusty\
\
References:
http://www.novell.com/communities/node/7066/accessing-file-systems-disk-block-image-files
