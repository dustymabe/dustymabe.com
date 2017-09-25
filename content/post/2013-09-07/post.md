---
title: "Convert an Existing System to Use Thin LVs"
tags:
date: "2013-09-07"
published: true
---

#### *Introduction*

\
Want to take advantage of the efficiency and improved snapshotting of
thin LVs on an existing system? It will take a little work but it is
possible. The following steps will show how to convert a CentOS 6.4
basic installation to use thin logical volumes for the root device
(containing the root filesystem).

#### *Preparation*

\
To kick things off there are few preparation steps we need that seem a
bit unreleated but will prove useful. First I enabled `LVM` to issue
discards to underlying block devices (if you are interested in why this
is needed you can check out my post
[here.](/2013/06/21/guest-discardfstrim-on-thin-lvs/) )\
\

```nohighlight
[root@Cent64 ~]# cat /etc/lvm/lvm.conf | grep issue_discards
    issue_discards = 0
[root@Cent64 ~]# sed -i -e 's/issue_discards = 0/issue_discards = 1/' /etc/lvm/lvm.conf
[root@Cent64 ~]# cat /etc/lvm/lvm.conf | grep issue_discards
    issue_discards = 1
```

\
Next, since we are converting the whole system to use thin LVs we need
to enable our `initramfs` to mount and switch root to a thin LV. By
default `dracut` does not include the utilities that are needed to do
this (see
[BZ\#921235](https://bugzilla.redhat.com/show_bug.cgi?id=921235) ). This
means we need to tell dracut to add `thin_dump`, `thin_restore`, and
`thin_check` (provided by the device-mapper-persistent-data rpm) to the
initramfs. We also want to make sure they get added for any future
initramfs building so we will add it to a file within
`/usr/share/dracut/modules.d/`.\
\

```nohighlight
[root@Cent64 ~]# mkdir /usr/share/dracut/modules.d/99thinlvm
[root@Cent64 ~]# cat << EOF > /usr/share/dracut/modules.d/99thinlvm/install
> #!/bin/bash
> dracut_install -o thin_dump thin_restore thin_check
> EOF
[root@Cent64 ~]# chmod +x /usr/share/dracut/modules.d/99thinlvm/install
[root@Cent64 ~]# dracut --force
[root@Cent64 ~]# lsinitrd /boot/initramfs-2.6.32-358.el6.x86_64.img | grep thin_
-rwxr-xr-x   1 root     root       351816 Sep  3 23:11 usr/sbin/thin_dump
-rwxr-xr-x   1 root     root       238072 Sep  3 23:11 usr/sbin/thin_check
-rwxr-xr-x   1 root     root       355968 Sep  3 23:11 usr/sbin/thin_restore
```

\
OK, so now that we have an adequate initramfs the final step before the
conversion is to make sure there is enough free space in the VG to move
our data around (in the worst case scenario we will need twice the space
we are currently using). On my system I just added a 2nd disk (`sdb`)
and added that disk to the VG:\
\

```nohighlight
[root@Cent64 ~]# lsblk
NAME                         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0                           11:0    1 1024M  0 rom  
sdb                            8:16   0   31G  0 disk 
sda                            8:0    0   30G  0 disk 
├─sda1                         8:1    0  500M  0 part /boot
└─sda2                         8:2    0 29.5G  0 part 
  ├─vg_cent64-lv_root (dm-0) 253:0    0 25.6G  0 lvm  /
  └─vg_cent64-lv_swap (dm-1) 253:1    0    4G  0 lvm  [SWAP]
[root@Cent64 ~]# 
[root@Cent64 ~]# vgextend vg_cent64 /dev/sdb
  Volume group "vg_cent64" successfully extended
[root@Cent64 ~]# 
[root@Cent64 ~]# vgs
  VG        #PV #LV #SN Attr   VSize  VFree 
  vg_cent64   2   2   0 wz--n- 60.50g 31.00g
```

#### *Conversion*

\
Now comes the main event! We need to create a thin LV pool and then move
the root LV over to the pool. Since thin pools currently cannot be
reduced in size (
[BZ\#812731](https://bugzilla.redhat.com/show_bug.cgi?id=812731)) I
decided to make my thin pool be exactly the size of the LV I wanted to
put in the pool. Below I show creating the thin pool as well as the
`thin_root` that will be our new *"thin"* root logical volume.\
\

```nohighlight
[root@Cent64 ~]# lvs --units=b /dev/vg_cent64/lv_root
  LV      VG        Attr      LSize        Pool Origin Data%  Move Log Cpy%Sync Convert
  lv_root vg_cent64 -wi-ao--- 27455913984B                                             
[root@Cent64 ~]# 
[root@Cent64 ~]# lvcreate -T vg_cent64/thinp --size=27455913984B
  Logical volume "thinp" created
[root@Cent64 ~]# 
[root@Cent64 ~]# lvcreate -T vg_cent64/thinp -n thin_root -V 27455913984B
  Logical volume "thin_root" created
[root@Cent64 ~]# 
[root@Cent64 ~]# lvs
  LV        VG        Attr      LSize  Pool  Origin Data%  Move Log Cpy%Sync Convert
  lv_root   vg_cent64 -wi-ao--- 25.57g                                              
  lv_swap   vg_cent64 -wi-ao---  3.94g                                              
  thin_root vg_cent64 Vwi-a-tz- 25.57g thinp          0.00                          
  thinp     vg_cent64 twi-a-tz- 25.57g                0.00
```

\
Now we need to get all of the data from `lv_root` and into `thin_root`.
My original thought is just to `dd` all of the content from one to the
other, but there is one problem: we are still mounted on `lv_root`. For
safety I would probably recommend booting into a rescue mode from a cd
and then doing the `dd` without either filesystem mounted. However,
today I just decided to make an LVM snapshot of the root LV which gives
us a consistent view of the block device for the duration of the copy.\
\

```nohighlight
[root@Cent64 ~]# lvcreate --snapshot -n snap_root --size=2g vg_cent64/lv_root
  Logical volume "snap_root" created
[root@Cent64 ~]# 
[root@Cent64 ~]# dd if=/dev/vg_cent64/snap_root of=/dev/vg_cent64/thin_root
53624832+0 records in
53624832+0 records out
27455913984 bytes (27 GB) copied, 597.854 s, 45.9 MB/s
[root@Cent64 ~]# 
[root@Cent64 ~]# lvs
  LV        VG        Attr      LSize  Pool  Origin  Data%  Move Log Cpy%Sync Convert
  lv_root   vg_cent64 owi-aos-- 25.57g                                               
  lv_swap   vg_cent64 -wi-ao---  3.94g                                               
  snap_root vg_cent64 swi-a-s--  2.00g       lv_root   0.07                          
  thin_root vg_cent64 Vwi-a-tz- 25.57g thinp         100.00                          
  thinp     vg_cent64 twi-a-tz- 25.57g               100.00                          
[root@Cent64 ~]#
[root@Cent64 ~]# lvremove /dev/vg_cent64/snap_root 
Do you really want to remove active logical volume snap_root? [y/n]: y
  Logical volume "snap_root" successfully removed
```

\
So there we have it. All of the data has been copied to the `thin_root`
LV. You can see from the output of `lvs` that the thin LV and the thin
pool are both 100% full. 100% full? really? I thought these were
*"thin"* LVs. :)\
\
Let's recover that space! I'll do this by mounting `thin_root` and then
running `fstrim` to release the unused blocks back to the pool. First I
check the fs and clean up any dirt by running `fsck`.\
\

```nohighlight
[root@Cent64 ~]# fsck /dev/vg_cent64/thin_root 
fsck from util-linux-ng 2.17.2
e2fsck 1.41.12 (17-May-2010)
Clearing orphaned inode 1047627 (uid=0, gid=0, mode=0100700, size=0)
Clearing orphaned inode 1182865 (uid=0, gid=0, mode=0100755, size=15296)
Clearing orphaned inode 1182869 (uid=0, gid=0, mode=0100755, size=24744)
Clearing orphaned inode 1444589 (uid=0, gid=0, mode=0100755, size=15256)
...
/dev/mapper/vg_cent64-thin_root: clean, 30776/1676080 files, 340024/6703104 blocks
[root@Cent64 ~]# 
[root@Cent64 ~]# mount /dev/vg_cent64/thin_root /mnt/
[root@Cent64 ~]# 
[root@Cent64 ~]# fstrim -v /mnt/
/mnt/: 26058436608 bytes were trimmed
[root@Cent64 ~]# 
[root@Cent64 ~]# lvs
  LV        VG        Attr      LSize  Pool  Origin Data%  Move Log Cpy%Sync Convert
  lv_root   vg_cent64 -wi-ao--- 25.57g                                              
  lv_swap   vg_cent64 -wi-ao---  3.94g                                              
  thin_root vg_cent64 Vwi-aotz- 25.57g thinp          5.13                          
  thinp     vg_cent64 twi-a-tz- 25.57g                5.13
```
\
Success! All the way from 100% back down to 5%.\
\
Now let's update the `grub.conf` and the `fstab` to use the new
`thin_root` LV.\
\
**NOTE:** `grub.conf` is on the filesystem on `sda1`.\
**NOTE:** `fstab` is on the filesystem on `thin_root`.\
\

```nohighlight
[root@Cent64 ~]# sed -i -e 's/lv_root/thin_root/g' /boot/grub/grub.conf
[root@Cent64 ~]# sed -i -e 's/lv_root/thin_root/g' /mnt/etc/fstab
[root@Cent64 ~]# umount /mnt/
```

\
Time for a reboot!\
\
After the system comes back up we should now be able to delete the
original `lv_root`.\
\

```nohighlight
[root@Cent64 ~]# lvremove /dev/vg_cent64/lv_root 
Do you really want to remove active logical volume lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed
```

\
Now we want to remove that extra disk (`/dev/sdb`) I added. However
there is a subtle difference between my system now and my system before.
There is metadata LV (`thinp_tmeta`) that is taking up a minute amount
of space that is preventing us from being able to fit completely on the
first disk (`/dev/sda`).\
\
No biggie. We'll just steal this amount of space from `lv_swap`. And
then run `pvmove` to move all data back to `/dev/sda`.\
\

```nohighlight
[root@Cent64 ~]# lvs -a --units=b 
  LV            VG        Attr      LSize        Pool  Origin Data%  Move Log Cpy%Sync Convert
  lv_swap       vg_cent64 -wi-ao---  4227858432B                                              
  thin_root     vg_cent64 Vwi-aotz- 27455913984B thinp          5.13                                          
  thinp         vg_cent64 twi-a-tz- 27455913984B                5.13                          
  [thinp_tdata] vg_cent64 Twi-aot-- 27455913984B                                              
  [thinp_tmeta] vg_cent64 ewi-aot--    29360128B
[root@Cent64 ~]# 
[root@Cent64 ~]# swapoff /dev/vg_cent64/lv_swap 
[root@Cent64 ~]# 
[root@Cent64 ~]# lvresize --size=-29360128B /dev/vg_cent64/lv_swap
  WARNING: Reducing active logical volume to 3.91 GiB
  THIS MAY DESTROY YOUR DATA (filesystem etc.)
Do you really want to reduce lv_swap? [y/n]: y
  Reducing logical volume lv_swap to 3.91 GiB
  Logical volume lv_swap successfully resized
[root@Cent64 ~]# 
[root@Cent64 ~]# mkswap /dev/vg_cent64/lv_swap 
mkswap: /dev/vg_cent64/lv_swap: warning: don't erase bootbits sectors
        on whole disk. Use -f to force.
Setting up swapspace version 1, size = 4100092 KiB
no label, UUID=7b023342-a9a9-4676-8bc6-1e60541010e4
[root@Cent64 ~]# 
[root@Cent64 ~]# swapon -v /dev/vg_cent64/lv_swap 
swapon on /dev/vg_cent64/lv_swap
swapon: /dev/mapper/vg_cent64-lv_swap: found swap signature: version 1, page-size 4, same byte order
swapon: /dev/mapper/vg_cent64-lv_swap: pagesize=4096, swapsize=4198498304, devsize=4198498304
```

\
Now we can get rid of `sdb` by running `pvmove` and `vgreduce`.\
\

```nohighlight
[root@Cent64 ~]# pvmove /dev/sdb
  /dev/sdb: Moved: 0.1%
  /dev/sdb: Moved: 11.8%
  /dev/sdb: Moved: 21.0%
  /dev/sdb: Moved: 32.0%
  /dev/sdb: Moved: 45.6%
  /dev/sdb: Moved: 56.2%
  /dev/sdb: Moved: 68.7%
  /dev/sdb: Moved: 79.6%
  /dev/sdb: Moved: 90.7%
  /dev/sdb: Moved: 100.0%
[root@Cent64 ~]# 
[root@Cent64 ~]# pvs
  PV         VG        Fmt  Attr PSize  PFree 
  /dev/sda2  vg_cent64 lvm2 a--  29.51g     0 
  /dev/sdb   vg_cent64 lvm2 a--  31.00g 31.00g
[root@Cent64 ~]#
[root@Cent64 ~]# vgreduce vg_cent64 /dev/sdb 
  Removed "/dev/sdb" from volume group "vg_cent64"
```

\
Boom! You're done!\
\
Dusty
