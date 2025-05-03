---
title: "BTRFS: How big are my snapshots?"
tags:
date: "2013-09-22"
draft: false
---

#### *Introduction*

\
I have been using BTRFS snapshots for a while now on my laptop to
incrementally save the state of my machine before I perform system
updates or run some harebrained test. I quickly ran into a problem
though, as on a smaller filesystem I was running out of space. I then
wanted to be able to look at each snapshot and easily determine how much
space I could **recover** if I deleted each snapshot. Surprisingly this
information was not readily available. Of course you could determine the
total size of each snapshot by using `du`, but that only tells you how
big the entire snapshot is and not how much of the snapshot is exclusive
to this snapshot only..\
\
Enter filesystem quota and qgroups in git commit
[89fe5b5f666c247aa3173745fb87c710f3a71a4a](http://git.kernel.org/cgit/linux/kernel/git/mason/btrfs-progs.git/commit/?id=89fe5b5f666c247aa3173745fb87c710f3a71a4a)
. With quota and qgroups (see an overview
[here](http://sensille.com/qgroups.pdf) ) we can now see how big each of
those snapshots are, including exclusive usage.

#### *Steps*

\
The system I am using for this example is Fedora 19 with
btrfs-progs-0.20.rc1.20130308git704a08c-1.fc19.x86\_64 installed. I have
a 2nd disk attached (`/dev/sdb`) that I will use for the BTRFS
filesystem.\
\
First things first lets create a BTRFS filesystem on `sdb`, mount the
filesystem and then create a .snapshots directory.\
\

```nohighlight
[root@localhost ~]# mkfs.btrfs /dev/sdb

WARNING! - Btrfs v0.20-rc1 IS EXPERIMENTAL
WARNING! - see http://btrfs.wiki.kernel.org before using

fs created label (null) on /dev/sdb
        nodesize 4096 leafsize 4096 sectorsize 4096 size 10.00GB
Btrfs v0.20-rc1
[root@localhost ~]# 
[root@localhost ~]# mount /dev/sdb /btrfs
[root@localhost ~]# mkdir /btrfs/.snapshots
```

\
Next lets copy some files into the filesystem. I will copy in a 50M file
and then create a snapshot (`snap1`). Then I will copy in a 4151M file
and take another snapshot (`snap2`). Finally, a 279M file and another
snapshot (`snap3`).\
\

```nohighlight
[root@localhost ~]# cp /root/50M_File /btrfs/
[root@localhost ~]# btrfs subvolume snapshot /btrfs /btrfs/.snapshots/snap1
Create a snapshot of '/btrfs' in '/btrfs/.snapshots/snap1'
[root@localhost ~]# 
[root@localhost ~]# cp /root/4151M_File /btrfs/
[root@localhost ~]# btrfs subvolume snapshot /btrfs /btrfs/.snapshots/snap2
Create a snapshot of '/btrfs' in '/btrfs/.snapshots/snap2'
[root@localhost ~]# 
[root@localhost ~]# cp /root/279M_File /btrfs/
[root@localhost ~]# btrfs subvolume snapshot /btrfs /btrfs/.snapshots/snap3
Create a snapshot of '/btrfs' in '/btrfs/.snapshots/snap3'
[root@localhost ~]# 
[root@localhost ~]# df -kh /btrfs/
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb         10G  4.4G  3.6G  55% /btrfs
```

\
Now how much is each one of those snapshots taking up? We can see this
information by enabling quota and then printing out the qgroup
information:\
\

```nohighlight
[root@localhost ~]# btrfs quota enable /btrfs/
[root@localhost ~]# 
[root@localhost ~]# btrfs qgroup show  /btrfs/
0/5 4698025984 8192
0/257 52432896 4096
0/263 4405821440 12288
0/264 4698025984 8192
```

\
The first number on each line represents the subvolume id. The second
number represents the amount of space contained within each subvolume
(in bytes) and the last number represents the amount of space that is
exclusive to that subvolume (in bytes). Now for some reason when I see
such large numbers I go brain dead and fail to comprehend how much space
is actually being used. I wrote a little perl
[script](/2013-09-22/convert) to convert the numbers to MB.\
\

```nohighlight
[root@localhost ~]# btrfs qgroup show  /btrfs/ | /root/convert
0/5     4480M   0M
0/257   50M     0M
0/263   4201M   0M
0/264   4480M   0M
```

\
So that makes sense. The 1st snapshot (denoted by the 2nd line) contains
50M. The 2nd snapshot contains 50M+4151M and the 3rd snapshot contains
50M+4151M+279M. We can also see that at the moment none of them have any
exclusive content. This is because all data is shared among them all.\
\
We can fix that by deleting some of the files.\
\

```nohighlight
[root@localhost ~]# rm /btrfs/279M_File
rm: remove regular file ‘/btrfs/279M_File’? y
[root@localhost ~]# btrfs qgroup show  /btrfs/ | /root/convert
0/5     4201M   0M
0/257   50M     0M
0/263   4201M   0M
0/264   4480M   278M
```

\
Now if we delete all of the files and view the qgroup info, what do we
see?\
\

```nohighlight
[root@localhost ~]# rm -f /btrfs/4151M_File
[root@localhost ~]# rm -f /btrfs/50M_File
[root@localhost ~]# btrfs qgroup show  /btrfs/ | /root/convert
0/5     0M      0M
0/257   50M     0M
0/263   4201M   0M
0/264   4480M   278M
```

\
We can see from the first line that the files have been removed from the
root subvolume but the exclusive counts didn't go up for snap1 and
snap2?\
\
This is because the files are shared with snap3. If we remove snap3 then
we'll see the exclusive number go up for snap2:\
\

```nohighlight
[root@localhost ~]# btrfs subvolume delete /btrfs/.snapshots/snap3
Delete subvolume '/btrfs/.snapshots/snap3'
[root@localhost ~]#
[root@localhost ~]# btrfs qgroup show  /btrfs/ | /root/convert
0/5     -4480M  -278M
0/257   50M     0M
0/263   4201M   4151M
0/264   4480M   278M
```

\
As expected the 2nd snapshot now shows 4151M as exclusive. However,
unexpectedly the qgroup for the 3rd snapshot still exists and the root
subvolume qgroup now shows negative numbers.\
\
Finally lets delete snap2 and observe that the amount of exclusive space
(4151M) is actually released back to the pool of free space:\
\

```nohighlight
[root@localhost ~]# df -kh /btrfs/
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb         10G  4.2G  3.9G  52% /btrfs
[root@localhost ~]#
[root@localhost ~]# btrfs subvolume delete /btrfs/.snapshots/snap2
Delete subvolume '/btrfs/.snapshots/snap2'
[root@localhost ~]#
[root@localhost ~]# btrfs qgroup show  /btrfs/ | /root/convert
0/5     -8682M  -4430M
0/257   50M     50M
0/263   4201M   4151M
0/264   4480M   278M
[root@localhost ~]#
[root@localhost ~]# df -kh /btrfs/
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb         10G   52M  8.0G   1% /btrfs
```

\
So we can see that the space is in fact released and is now counted as
free space. Again the negative numbers and the fact that the qgroups
show up for the deleted subvolumes is a bit odd.\
\
Cheers!\
\
Dusty Mabe\
\
**Bonus:** It seems like there is a patch floating around to enhance the
output of qgroup show. Check it out
[here](http://comments.gmane.org/gmane.comp.file-systems.btrfs/21545).
