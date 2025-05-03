---
title: "Thin LVM Snapshots: Why Size Is Less Important"
tags:
date: "2013-07-17"
draft: false
---

Traditionally with LVM snapshots you need to be especially careful when
choosing how big to make your snapshots; if it is too small it will fill
up and become *invalid*. If taking many snapshots with limited space
then it becomes quite difficult to decide which snapshots need more
space than others.\
\
One approach has been to leave some extra space in the VG and let
dmeventd periodically poll and `lvextend` the snapshot if necessary (I
covered this in a previous
[post](/2012/03/04/automatically-extend-lvm-snapshots/) ). However, a
reader of mine has pointed out that this polling mechanism does not work
very well for small snapshots.\
\
Fortunately, with the addition of thin logical volume support within LVM
(I believe initially in RHEL/CentOS 6.4 and/or Fedora 17), size is much
less important to consider when taking a snapshot. If you create a thin
LV and then *"snapshot"* the thin LV, what you actually end up with are
two thin LVs. They both use extents from the same pool and the size will
grow dynamically as needed.\
\
As always, examples help. In my system I have a 20G `sdb`. I'll create a
VG, `vgthin`, that uses `sdb` and then a 10G thin pool, `lvpool`, within
`vgthin`.\
\

```nohighlight
[root@localhost ~]# lsblk /dev/sdb
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sdb    8:16   0  20G  0 disk 
[root@localhost ~]# 
[root@localhost ~]# vgcreate vgthin /dev/sdb
  Volume group "vgthin" successfully created
[root@localhost ~]# 
[root@localhost ~]# lvcreate --thinpool lvpool --size 10G vgthin
  Logical volume "lvpool" created
```

\
Next, I'll create a thin LV (`lvthin`), add a filesystem and mount it.\
\

```nohighlight
[root@localhost ~]# lvcreate --name lvthin --virtualsize 5G --thin vgthin/lvpool
  Logical volume "lvthin" created
[root@localhost ~]# 
[root@localhost ~]# mkfs.ext4 /dev/vgthin/lvthin 
...
[root@localhost ~]# mkdir /mnt/origin
[root@localhost ~]# mount /dev/vgthin/lvthin /mnt/origin
[root@localhost ~]#  
[root@localhost ~]# lvs
  LV     VG     Attr      LSize  Pool   Origin Data%  Move Log Copy%  Convert
  lvpool vgthin twi-a-tz- 10.00g                 1.27                        
  lvthin vgthin Vwi-a-tz-  5.00g lvpool          2.54                        
```

\
I'll go ahead and create the snapshot now, but just as a sanity check
I'll create a file, `A`, that exists before the snapshot. After the
snapshot I'll create a file, `B`. This file should NOT be visible in the
snapshot if it is working properly.\
\

```nohighlight
[root@localhost ~]# touch /mnt/origin/A
[root@localhost ~]# 
[root@localhost ~]# lvcreate --name lvsnap --snapshot vgthin/lvthin 
  Logical volume "lvsnap" created
[root@localhost ~]# 
[root@localhost ~]# mkdir /mnt/snapshot
[root@localhost ~]# mount /dev/vgthin/lvsnap /mnt/snapshot/
[root@localhost ~]# 
[root@localhost ~]# touch /mnt/origin/B
[root@localhost ~]# 
[root@localhost ~]# ls /mnt/origin/
A  B  lost+found
[root@localhost ~]# ls /mnt/snapshot/
A  lost+found
```

\
Perfect! Snapshotting is working as expected. What are our
utilizations?\
\

```nohighlight
[root@localhost ~]# lvs
  LV     VG     Attr      LSize  Pool   Origin Data%  Move Log Copy%  Convert
  lvpool vgthin twi-a-tz- 10.00g                 2.05                        
  lvsnap vgthin Vwi-aotz-  5.00g lvpool lvthin   4.10                        
  lvthin vgthin Vwi-aotz-  5.00g lvpool          4.10                        
```

\
Since we just created the snapshot our current utilization for both
`lvthin` and `lvsnap` are the same. Take note also that the overall data
usage for the entire pool actually shows us that `lvthin` and `lvsnap`
are sharing the blocks that were present at the time the snapshot was
taken. This will continue to be true as long as those blocks don't
change.\
\
A few more sanity checks.. If we add a 1G file into the filesystem on
`lvthin` we should see only the usage of `lvthin` increase.\
\

```nohighlight
[root@localhost ~]# cp /root/1Gfile /mnt/origin/
[root@localhost ~]# lvs
  LV     VG     Attr      LSize  Pool   Origin Data%  Move Log Copy%  Convert
  lvpool vgthin twi-a-tz- 10.00g                12.06                        
  lvsnap vgthin Vwi-aotz-  5.00g lvpool lvthin   4.10                        
  lvthin vgthin Vwi-aotz-  5.00g lvpool         24.10                        
```

\
If we add a 512M file into the snapshot then we should see only the
usage of `lvsnap` increase.\
\

```nohighlight
[root@localhost ~]# cp /root/512Mfile /mnt/snapshot/
[root@localhost ~]# lvs
  LV     VG     Attr      LSize  Pool   Origin Data%  Move Log Copy%  Convert
  lvpool vgthin twi-a-tz- 10.00g                17.06                        
  lvsnap vgthin Vwi-aotz-  5.00g lvpool lvthin  14.10                        
  lvthin vgthin Vwi-aotz-  5.00g lvpool         24.10                        
```

\
And thats it.. Not that exciting, but it is dynamic allocation of
snapshots (did I also mention there is support for snapshots of
snapshots of snapshots?). As long as there is still space within the
pool the snapshot will grow dynamically.\
\
Cheers\
\
Dusty
