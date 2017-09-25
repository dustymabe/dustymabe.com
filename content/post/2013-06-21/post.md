---
title: "Guest Discard/FSTRIM On Thin LVs"
tags:
date: "2013-06-21"
published: true
url: "/2013/06/21/guest-discardfstrim-on-thin-lvs/"
---

In my last
[post](/2013/06/11/recover-space-from-vm-disk-images-by-using-discardfstrim/)
I showed how to recover space from disk images backed by sparse files.
As a small addition I'd like to also show how to do the same with a
guest disk image that is backed by a [thinly provisioned Logical
Volume.](http://www.redhat.com/archives/linux-lvm/2012-January/msg00018.html)\
\
First things first, I modified the `/etc/lvm/lvm.conf` file to have the
`issue_discards = 1` option set. I'm not 100% sure this is needed but I
did it at the time so I wanted to include it here.\
\
Next I created a new VG (`vgthin`) out of a spare partition and then
created an thin LV pool (`lvthinpool`) inside the VG. Finally I created
a thin LV within the pool (`lvthin`). This is all shown below:\
\

```nohighlight
[root@host ~]# vgcreate vgthin /dev/sda3
  Volume group "vgthin" successfully created
[root@host ~]# lvcreate --thinpool lvthinpool --size 20G vgthin
  Logical volume "lvthinpool" created
[root@host ~]# 
[root@host ~]# lvcreate --name lvthin --virtualsize 10G --thin vgthin/lvthinpool
  Logical volume "lvthin" created
```

\
To observe the usages of the thin LV and the thin pool you can use the
`lvs` command and take note of the Data% column:\
\

```nohighlight
[root@host ~]# lvs vgthin
  LV         VG     Attr      LSize  Pool       Origin Data%  Move Log Copy%  Convert
  lvthin     vgthin Vwi-aotz- 10.00g lvthinpool          0.00                        
  lvthinpool vgthin twi-a-tz- 20.00g                     0.00
```

\
Next I needed to add the disk to the guest. I did it using the following
xml and `virsh` command. Note from my previous post that the scsi
controller inside of my guest is a `virtio-scsi` controller and that I
am adding the `discard='unmap'` option.\
\

```nohighlight
[root@host ~]# cat <<EOF > /tmp/thinLV.xml 
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw' discard='unmap'/>
      <source dev='/dev/vgthin/lvthin'/>
      <target dev='sdb' bus='scsi'/>
    </disk>
EOF
[root@host ~]#
[root@host ~]# virsh attach-device Fedora19 /tmp/thinLV.xml --config 
...
```

\
After a quick power cycle of the guest I then created a filesystem on
the new disk (`sdb`) and mounted it within the guest.\
\

```nohighlight
[root@guest ~]# mkfs.ext4 /dev/sdb 
...
[root@guest ~]# 
[root@guest ~]# mount /dev/sdb /mnt/
```

\
Same as last time, I then copied a large file into the guest. After I
did so you can see from the `lvs` output that the thin LV is now using
11% of its allotted space within the pool.\
\

```nohighlight
[root@host ~]# lvs vgthin
  LV         VG     Attr      LSize  Pool       Origin Data%  Move Log Copy%  Convert
  lvthin     vgthin Vwi-aotz- 10.00g lvthinpool          1.34                        
  lvthinpool vgthin twi-a-tz- 20.00g
[root@host ~]# 
[root@host ~]# scp /tmp/code.tar.gz root@192.168.100.136:/mnt/
root@192.168.100.136's password: 
code.tar.gz                        100% 1134MB  29.8MB/s   00:38     
[root@host ~]# 
[root@host ~]# lvs vgthin
  LV         VG     Attr      LSize  Pool       Origin Data%  Move Log Copy%  Convert
  lvthin     vgthin Vwi-aotz- 10.00g lvthinpool         11.02                        
  lvthinpool vgthin twi-a-tz- 20.00g
```

\
It was then time for a little TRIM action:\
\

```nohighlight
[root@guest ~]# df -kh /mnt/
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb        9.8G  1.2G  8.1G  13% /mnt
[root@guest ~]# 
[root@guest ~]# 
[root@guest ~]# rm /mnt/code.tar.gz 
rm: remove regular file ‘/mnt/code.tar.gz’? y
[root@guest ~]# 
[root@guest ~]# df -kh /mnt/
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb        9.8G   23M  9.2G   1% /mnt
[root@guest ~]# fstrim -v /mnt/
/mnt/: 1.2 GiB (1329049600 bytes) trimmed
```

\
And from within the host we can see that the utilization of the thin LV
has appropriately dwindled back down to \~2.85%\
\

```nohighlight
[root@host ~]# lvs vgthin
  LV         VG     Attr      LSize  Pool       Origin Data%  Move Log Copy%  Convert
  lvthin     vgthin Vwi-aotz- 10.00g lvthinpool          2.85                        
  lvthinpool vgthin twi-a-tz- 20.00g                     1.42
```

\
Again I have posted my full guest libvirt XML
[here.](/2013-06-21/guest.xml)\
\
Dusty\
\
PS See
[here](http://lxadm.wordpress.com/2012/10/17/lvm-thin-provisioning/) for
a more thorough example of creating thin LVs.
