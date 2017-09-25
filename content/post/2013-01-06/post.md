---
title: "OS Upgrade and Rollback Using BTRFS"
tags:
date: "2013-01-06"
published: true
---

I recently decided to try out the snapshotting capabilities of the
relatively new [BTRFS](http://en.wikipedia.org/wiki/Btrfs) filesystem. I
have been using the snapshot and rollback capability of LVM (using
`lvconvert --merge`) for a while now so I figured I would check out
BTRFS to see how it stacks up.\
\
To get up to speed on how to use BTRFS I found the [BTRFS
Fun](http://www.funtoo.org/wiki/BTRFS_Fun) web page a good reference. I
converted an existing Fedora 17 virtual machine to use BTRFS for the
filesystems (I may cover how I did this in a later post). The *disk*
inside the virtual machine contains three partitions as is shown below:\
\

```nohighlight
[root@guest1 ~]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0     11:0    1  4.2G  0 rom
vda    252:0    0   20G  0 disk
├─vda1 252:1    0  500M  0 part /boot
├─vda2 252:2    0    4G  0 part [SWAP]
└─vda3 252:3    0 15.6G  0 part /
[root@guest1 ~]#
```

\
As you can see from the output, `vda1` is for `/boot` while `vda3` is
for `/`; the root partition. After converting from ext4, both `vda1` and
`vda3` have BTRFS ***volumes*** (filesystems) on them. Now I am free to
snapshot them as I please.\

#### *Taking The Snapshots*

\
In BTRFS snapshots are actually ***subvolumes*** (see
[here](http://www.funtoo.org/wiki/BTRFS_Fun#Playing_with_subvolumes_and_snapshots)
for an explanation of subvolumes). This means when I create a snapshot
of `/boot` and `/` it is actually creating a subvolume.\
\
To create the snapshots you use the `btrfs subvolume snapshot` command
and you must specify where in the filesystem you want the snapshot to
reside. To help myself not get confused I created a `/boot/.snapshots`
directory and a `/.snapshots` directory which is where I will create the
snapshots. The creation of the snapshots is shown below:\
\

```nohighlight
[root@guest1 ~]# mkdir /boot/.snapshots
[root@guest1 ~]# mkdir /.snapshots
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume snapshot /boot /boot/.snapshots/snap1
Create a snapshot of '/boot' in '/boot/.snapshots/snap1'
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume snapshot / /.snapshots/snap1
Create a snapshot of '/' in '/.snapshots/snap1'
[root@guest1 ~]#
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume list /boot
ID 256 top level 5 path .snapshots/snap1
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume list /
ID 270 top level 5 path .snapshots/snap1
[root@guest1 ~]#
```

\
If you notice in the output of the `btrfs subvolume list` commands
above, the subvolumes (snapshots) that were created have a unique ID
associated with them. For each BTRFS filesystem there is also an
implicit "***root subvolume***" with an ID of `0`.\
\
These IDs can be used to set which subvolume is the one that is used
when the BTRFS filesystem is mounted. In order to be able to easily
identify if I had mounted a snapshot or the root subvolume, I placed a
single file `snap1_sub` into the root directory of each snapshot.\
\

```nohighlight
[root@guest1 ~]# touch /boot/.snapshots/snap1/snap1_sub
[root@guest1 ~]#
[root@guest1 ~]# touch /.snapshots/snap1/snap1_sub
```

#### *Upgrade From F17 to F18 Beta*

\
At this point the snapshots were all set up and I could go ahead with
upgrading from Fedora 17 to the Fedora 18 beta. I followed the steps
from the [Fedora Web
Site](https://fedoraproject.org/wiki/Upgrading_Fedora_using_yum) on how
to do this. After rebooting I indeed had upgraded to Fedora 18:\

```nohighlight
[root@guest1 ~]# cat /etc/redhat-release
Fedora release 18 (Spherical Cow)
[root@guest1 ~]#
```

\
However, as usual the upgrade didn't yield a perfectly working system.
As far as the command line was concerned everything seemed to be fine
but my desktop session was a no go and the logs indicated there was
something awry with the X configuration.\
\
No need to fear! The snapshots are there!

#### *Reverting The Snapshots*

\
What we want to do now is revert the changes and go back to Fedora 17.
How do we do that?\
\
One way is to make the snapshot subvolume be the default subvolume that
is used when the filesystem is mounted. I set both `/boot` and `/` to
default to their snapshots by using the `btrfs subvolume set-default`
command:\
\

```nohighlight
[root@guest1 ~]# btrfs subvolume list /boot/
ID 256 gen 29 top level 5 path .snapshots/snap1
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume set-default 256 /boot/
[root@guest1 ~]#
[root@guest1 ~]#
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume list /
ID 270 gen 139 top level 5 path .snapshots/snap1
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume set-default 270 /
[root@guest1 ~]#
[root@guest1 ~]# reboot
```

\
After a quick reboot I was back up and running. I wanted to verify I was
in the snapshot so I checked to see if the files I had created were in
the root of the filesystems:\
\

```nohighlight
[root@guest1 ~]# ls -l /boot/snap1_sub
-rw-r--r-- 1 root root 0 Jan  4 23:20 /boot/snap1_sub
[root@guest1 ~]#
[root@guest1 ~]# ls -l /snap1_sub
-rw-r--r-- 1 root root 0 Jan  4 23:20 /snap1_sub
[root@guest1 ~]#
[root@guest1 ~]# cat /etc/redhat-release
Fedora release 17 (Beefy Miracle)
```

\
The next step was to restore the root subvolume (ID=0) of each
filesystem. I started with `/boot` (from `vda1`). To do this you mount
the root subvolume and then use `rsync` to restore any files that were
changed.\
\
**NOTE:** In the `rsync` command I was careful to exclude the file that
I created to let me know I was in the snapshot as well as the directory
that is used for the snapshots.\
\

```nohighlight
[root@guest1 ~]# mount -o subvolid=0 /dev/vda1 /mnt
[root@guest1 ~]#
[root@guest1 ~]# time rsync --delete -avHAX --exclude=snap1_sub --exclude=/.snapshots /boot/ /mnt/
sending incremental file list
./
deleting vmlinuz-3.6.10-4.fc18.x86_64
deleting initrd-plymouth.img
deleting initramfs-3.6.10-4.fc18.x86_64.img
deleting config-3.6.10-4.fc18.x86_64
deleting System.map-3.6.10-4.fc18.x86_64
deleting .vmlinuz-3.6.10-4.fc18.x86_64.hmac
grub/
grub/splash.xpm.gz
grub2/
grub2/grub.cfg
grub2/themes/
grub2/themes/system/
deleting grub2/themes/system/unicode.pf2
deleting grub2/themes/system/fireworks.png
deleting grub2/themes/system/DejaVuSans-Bold-14.pf2
deleting grub2/themes/system/DejaVuSans-12.pf2
deleting grub2/themes/system/DejaVuSans-10.pf2
grub2/themes/system/background.png
grub2/themes/system/dejavu.pf2
grub2/themes/system/theme.txt

sent 4216333 bytes  received 234 bytes  8433134.00 bytes/sec
total size is 36454169  speedup is 8.65

real    0m0.135s
user    0m0.023s
sys     0m0.018s
[root@guest1 ~]#
```

\
From the output we can see that upgrading caused about 34M (36454169
bytes) of changes to the filesystem and it took less than a second to
revert the changes.\
\
Now that the `/boot` filesystem has been restored we need to set the
default subvolume to mount again. We need to reset it back to
automatically mount the root subvolume.\
\
**NOTE:** When setting the default subvolume you have to be careful and
make sure to specify the location where the root subvolume is mounted
(in this case `/mnt`). There is a small bit of text that attempts to
explain why this is necessary on the [BTRFS
Fun](http://www.funtoo.org/wiki/BTRFS_Fun#Way_.231:_Fiddle_with_the_default_subvolume_number)
web page.\

```nohighlight
[root@guest1 ~]# btrfs subvolume set-default 0 /mnt
[root@guest1 ~]# umount /mnt
```

\
Now on to the `/` filesystem. For this one I needed to tweak the `rsync`
command to make sure that it didn't attempt to sync anything outside of
the filesystem; we don't care to sync fake filesystems like `/dev`
`/proc` `/sys` etc.. Also we wanted to exclude `/mnt` since that is
where the root subvolume is mounted.\
\

```nohighlight
[root@guest1 ~]# mount -o subvolid=0 /dev/vda3 /mnt
[root@guest1 ~]#
[root@guest1 ~]# time rsync --one-file-system --delete -avHAX --exclude=/snap1_sub --exclude=/.snapshots --exclude=/mnt / /mnt 
sending incremental file list
...
...
sent 2822450331 bytes  received 3425590 bytes  5429156.43 bytes/sec
total size is 3109809657  speedup is 1.10

real    8m40.348s
user    0m19.899s
sys     0m36.568s
[root@guest1 ~]#
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume set-default 0 /mnt
[root@guest1 ~]# umount /mnt
[root@guest1 ~]#
[root@guest1 ~]# reboot
```

\
And we are done.. It took less than 10 minutes to revert \~3G of changes
that were made. After the reboot my Fedora 17 instance was fully
restored and we were in the root subvolumes as can be seen below from
the absence of the `snap1_sub` files that I had created.\
\

```nohighlight
[root@guest1 ~]# cat /etc/redhat-release
Fedora release 17 (Beefy Miracle)
[root@guest1 ~]#
[root@guest1 ~]# ls -l /boot/snap1_sub
ls: cannot access /boot/snap1_sub: No such file or directory
[root@guest1 ~]#
[root@guest1 ~]# ls -l /snap1_sub
ls: cannot access /snap1_sub: No such file or directory
[root@guest1 ~]#
[root@guest1 ~]#
```

\
The final step was to delete the snapshots as they are no longer
needed.\
\

```nohighlight
[root@guest1 ~]# btrfs subvolume delete /boot/.snapshots/snap1
Delete subvolume '/boot/.snapshots/snap1'
[root@guest1 ~]#
[root@guest1 ~]# btrfs subvolume delete /.snapshots/snap1
Delete subvolume '/.snapshots/snap1'
```

#### *Conclusions*

Overall I believe the snapshotting feature of BTRFS is quite useful. I
like the fact that you don't have to carve out new storage for the
snapshots like in LVM, but at the same time I don't like how it doesn't
seem to be very easy to detect how much space the snapshots are using
up. I also don't like the fact that reverting the snapshots are a bit
*manual* and require an external tool like `rsync`. In LVM it is handled
all in one command: `lvconvert --merge`. That being said, just from
experience it does seem that reverting the snapshots seems to be a bit
faster with BTRFS than with LVM snapshots. I would have to run another
test to be sure of this.\
Happy New Year Everyone!\
\
Dusty\
\
References:\
\
http://www.funtoo.org/wiki/BTRFS\_Fun\
https://c59951.ssl.cf2.rackcdn.com/4376-bacik\_0.pdf
