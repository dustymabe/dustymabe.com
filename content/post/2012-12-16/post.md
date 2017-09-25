---
title: "Mount Complex Disk Images Using libguestfs"
tags:
date: "2012-12-16"
published: true
---

In my previous
[post](/2012/12/15/mounting-a-partition-within-a-disk-image/) I went
over two ways to mount a partition within a disk image file. There is
actually another easy way to do this by utilizing some of the tools that
the *virt* community has provided us in recent years.\
\
[libguestfs](http://libguestfs.org/) is a fairly comprehensive library
for manipulating guest disk images and filesystems. It turns out that
the tools work pretty well even for disk images that aren't specific to
any virtualized guest; after all a disk image is a disk image.\
\
The `guestmount` utility is provided as part of the *libguestfs-tools-c*
package in Fedora 17 and allows us the ability to (in)directly mount the
second partition of our disk image. This is shown below:\
\

```nohighlight
dustymabe@media: > guestmount -a /mnt/lenovo.img -m /dev/sda2 --ro /tmp/mnt
dustymabe@media: > ls /tmp/mnt/Users/
All Users  Default  Default User  desktop.ini  dustymabe  Public
```

\
The only drawback I can see at this point from using this tool is that
it is using [fuse](http://fuse.sourceforge.net/) under the covers to
mount the filesystem. This has some advantages and disadvantages but
typically results in lower performance. Nevertheless, `guestmount` and
the other tools provided by *libguestfs* are no doubt becoming very
useful for manipulating disk images.\
\
Cheers!\
\
Dusty Mabe
