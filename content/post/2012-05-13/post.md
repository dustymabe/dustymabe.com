---
title: "Easily Resize LVs and Underlying Filesystems"
tags:
date: "2012-05-13"
draft: false
---

Part of the reason I use Logical Volumes for my block devices rather
than standard partitions is because LVs are much more flexible when it
comes to sizing/resizing.\
\
For example, in a particular setup you might have a 1 TB hard drive that
you want to be broken up into two block devices. You could either choose
two 500 GB partitions, or two 500 GB LVs. If you use partitions and
later find out that you really needed 300 GB for one and 700 GB for the
other then resizing might get a little complicated. On the other hand,
with LVs resizing is simple!\
\
LVM has the ability to resize the LV and the underlying filesystem at
the same time (it uses ` fsadm` under the covers to resize the
filesystem which on my system supports resizing
ext2/ext3/ext4/ReiserFS/XFS). In order to pull this off simply use
` lvresize` along with the `--resizefs` option. An example of this
command is shown below:\
\

```nohighlight
dustymabe@fedorabook: tmp>sudo lvresize --size +1g --resizefs /dev/vg1/lv1
[sudo] password for dustymabe:
fsck from util-linux 2.19.1
/dev/mapper/vg1-lv1: clean, 11/262144 files, 51278/1048576 blocks
  Extending logical volume lv1 to 5.00 GiB
  Logical volume lv1 successfully resized
resize2fs 1.41.14 (22-Dec-2010)
Resizing the filesystem on /dev/mapper/vg1-lv1 to 1310720 (4k) blocks.
The filesystem on /dev/mapper/vg1-lv1 is now 1310720 blocks long.

dustymabe@fedorabook: tmp>
```

\
It should be noted that you can only do online resizing when you are
making an LV larger. If you are making it smaller then the filesystem
will most likely need to be unmounted.\
\
Happy Resizing!\
Dusty Mabe
