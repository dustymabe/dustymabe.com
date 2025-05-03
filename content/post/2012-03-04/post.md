---
title: "Automatically Extend LVM Snapshots"
tags:
date: "2012-03-04"
draft: false
---

[Snapshot logical
volumes](http://tldp.org/HOWTO/LVM-HOWTO/snapshotintro.html) are a great
way to save the state of an LV (a special block device) at a particular
point in time. Essentially this provides the ability to snapshot block
devices and then revert them back at a later date. In other words you
can rest easy when that big upgrade comes along :)\
\
This all seems fine and dandy until your snapshot runs out of space!
Yep, the size of the snapshot does matter. Snapshot LVs are
Copy-On-Write (COW) devices. **Old** blocks from the origin LV get
*"Copied"* to the snapshot LV only when **new** blocks are *"Written"*
to in the origin LV. Additionally, **only** the blocks that get written
to in the origin LV get copied over to the snapshot LV.\
\
Thus, you can make a snapshot LV much smaller than the origin LV and as
long as the snapshot never fills up then you are fine. If it does fill
up, then the snapshot is invalid and you can no longer use it.\
\
The problem with this is the fact that it becomes quite tricky to
determine how much space you actually need in your snapshot. If you
notice that your snapshot is becoming full then you can use `lvextend`
to increase the size of the snapshot, but this is not very desirable as
it's not automated and requires user intervention.\
\
The good news is that recently there was an addition to `lvm` that
allows for autoextension of snapshot LVs! The bugzilla report
[#427298](https://bugzilla.redhat.com/show_bug.cgi?id=427298) tracked the
request and it has now been released in lvm2-2.02.84-1. The lvm-devel
[email](http://www.redhat.com/archives/lvm-devel/2010-October/msg00010.html)
from when the patch came through contains some good details on how to
use the new functionality.\
\
To summarize, you edit `/etc/lvm/lvm.conf` and set the
`snapshot_autoextend_threshold` to something other than 100 (100 is the
default value and also disables automatic extension). In addition, you
also edit the `snapshot_autoextend_percent`. This value will be the
amount you want to extend the snapshot LV.\
\
To test this out I edited my `/etc/lvm/lvm.conf` file to have the
following values:\
\

```nohighlight
    snapshot_autoextend_threshold = 80
    snapshot_autoextend_percent = 20
```

\
These values indicate that once the snapshot is 80% full then extend
it's size by 20%. To get the `lvm` monitoring to pick up the changes the
`lvm2-monitor` service needs to be restarted (this varies by platform).\
\
Now, lets test it out! We will create an LV, make a filesystem, mount
it, and then snapshot the LV.\
\

```nohighlight
[root@F17 ~]#  lvcreate --size=1G --name=lv1 --addtag @lv1 vg1
  Logical volume "lv1" created
[root@F17 ~]#
[root@F17 ~]# mkfs.ext4 /dev/vg1/lv1 > /dev/null
mke2fs 1.42 (29-Nov-2011)
[root@F17 ~]#
[root@F17 ~]# mount /dev/vg1/lv1 /mnt/
[root@F17 ~]#
[root@F17 ~]# lvcreate --snapshot --size=500M --name=snap1 --addtag @lv1 /dev/vg1/lv1
  Logical volume "snap1" created
[root@F17 ~]#
```

\
Verify the snapshot was created by using `lvs`.\
\

```nohighlight
[root@F17 ~]# lvs -o lv_name,vg_name,lv_size,origin,snap_percent @lv1
  LV    VG   LSize   Origin Snap%
  lv1   vg1    1.00g
  snap1 vg1  500.00m lv1      0.00
```

\
Finally, I can test the snapshot autoextension. Since my snapshot is
500M in size let's create a file that is \~420M in the origin LV. This
will be just over 80% of the snapsphot size so it should get resized.\
\

```nohighlight
[root@F17 ~]# dd if=/dev/zero of=/mnt/file bs=1M count=420
420+0 records in
420+0 records out
440401920 bytes (440 MB) copied, 134.326 s, 3.3 MB/s
[root@F17 ~]#
[root@F17 ~]# ls -lh /mnt/file
-rw-r--r--. 1 root root 420M Mar  4 11:36 /mnt/file
```

\
A quick run of `lvs` reveals that the underlying monitoring code did
it's job and extended the LV by 20% to 600M!!\
\

```nohighlight
[root@F17 ~]# lvs -o lv_name,vg_name,lv_size,origin,snap_percent @lv1
  LV    VG   LSize   Origin Snap%
  lv1   vg1    1.00g
  snap1 vg1  600.00m lv1     70.29
[root@F17 ~]#
```

\
\
Dusty Mabe
