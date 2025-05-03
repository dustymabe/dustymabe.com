---
title: "Recover Space From VM Disk Images By Using Discard/FSTRIM"
tags:
date: "2013-06-11"
draft: false
url: "/2013/06/11/recover-space-from-vm-disk-images-by-using-discardfstrim/"
---

Sparse guest disk image files are a dream. I can have many guests on a
small amount of storage because they are only using what they need. Of
course, if each guest were to suddenly use all of the space in their
filesystems then the host filesystem containing the guest disk images
would fill up as well. However, since filesystems grow over time rather
than overnight, with proper monitoring you can foresee this event and
add more storage as needed.\
\
Sparse guest disk images aren't all bells and whistles though. Over time
files are created/deleted within the filesystems on the disk images and
the images themselves are no longer as compact as they were in the past.
There is good news though; we can recover the space from all of those
deleted files!

#### *A Little History*

\
With the rise of SSDs has come along a new low level command known as
[TRIM](http://en.wikipedia.org/wiki/TRIM) that allows the filesystem to
notify the underlying block device of blocks that are no longer in use
by the filesystem. This allows for improved performance in SSDs because
delete operations can be handled in advance of write operations, thus
speeding up writes.\
\
Fortunately for us this TRIM notification also has plenty of application
with thinly provisioned block devices. If the filesystem can notify a
thin LV or a sparse disk image of blocks that are no longer being used
then the blocks can be released back to the pool of available space.\
\
"So I should be able to recover space from my guest disk images, right?"
The answer is "yes"! It is relatively new, but virtio-scsi devices
(QEMU) support TRIM operations. This is available in QEMU 1.5.0 by
adding `discard=unmap` to the `-drive` option. You can also bypass the
QEMU command line by using Libvirt 1.0.6 and adding the `discard=unmap`
option to disk XML.

#### *Creating/Configuring Guest For Discard*

\
To take advantage of discard/TRIM operations I needed a guest that
utilizes virtio-scsi. I created a guest with a virtio-scsi backed device
by using the following `virt-install` command.\
\

```nohighlight
[root@host ~]# virt-install --name Fedora19       \
--disk path=/guests/Fedora19.img,size=30,bus=scsi \
--controller scsi,model=virtio-scsi               \
--network=bridge:virbr0,model=virtio              \
--accelerate --ram 2048 -c /images/F19.iso         
```

\
The XML that was generated clearly shows that scsi controller 0 is of
model ***virtio-scsi*** and thus all scsi devices on that controller
will be ***virtio-scsi*** devices.\
\

```nohighlight
<controller type='scsi' index='0' model='virtio-scsi'>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
</controller>
```

\
The next step was to actually notify QEMU that we want to relay discard
operations from the guest to the host. This is supported in QEMU 1.5.0
(since commit
[a9384aff5315e7568b6ebc171f4a482e01f06526](http://git.qemu.org/?p=qemu.git;a=commit;h=a9384aff5315e7568b6ebc171f4a482e01f06526)).
Fortunately libvirt also added support for this in version 1.0.6 (since
commit
[a7c4202cdd12208dcd107fde3b79b2420d863370](http://libvirt.org/git/?p=libvirt.git;a=commit;h=a7c4202cdd12208dcd107fde3b79b2420d863370)).\
\
For libvirt, to make all discard/TRIM operations be passed from the
guest back to the host I had to add the `discard='unmap'` to the disk
XML description. After adding the option the XML looked like the
following block:\
\

```nohighlight
<disk type='file' device='disk'>
  <driver name='qemu' type='raw' discard='unmap'/>
  <source file='/guests/Fedora19.img'/>
  <target dev='sda' bus='scsi'/>
  <address type='drive' controller='0' bus='0' target='0' unit='0'/>
</disk>
```

\

#### *Trimming The Fat*

\
After a power cycle of the guest I am now able to test it out. First I
checked the disk image size and then copied a 1.2G file into the guest.
Afterwards I confirmed the sparse disk image had increased size in the
host.\
\

```nohighlight
[root@host ~]# du -sh /guests/Fedora19.img 
1.1G    /guests/Fedora19.img
[root@host ~]# 
[root@host ~]# du -sh /tmp/code.tar.gz 
1.2G    /tmp/code.tar.gz
[root@host ~]# 
[root@host ~]# scp /tmp/code.tar.gz root@192.168.100.136:/root/
root@192.168.100.136's password: 
code.tar.gz                   100% 1134MB  81.0MB/s   00:14    :
[root@host ~]# 
[root@host ~]# du -sh /guests/Fedora19.img 
2.1G    /guests/Fedora19.img
```

\
Within the guest I then deleted the file and executed the `fstrim`
command in order to notify the block devices that the blocks for that
file (and any other file that had been deleted) are no longer being used
by the filesystem.\
\

```nohighlight
[root@guest ~]# rm /root/code.tar.gz 
rm: remove regular file ‘/root/code.tar.gz’? y
[root@guest ~]# 
[root@guest ~]# fstrim -v /
/: 1.3 GiB (1372569600 bytes) trimmed
```

\
As can be seen from the output of the `fstrim` command approximately
1.3G were trimmed. A final check of the guest disk image confirms that
the space was recovered in the host filesystem.\
\

```nohighlight
[root@host ~]# du -sh /guests/Fedora19.img 
1.1G    /guests/Fedora19.img
```

\
If anyone is interested I have posted my full guest libvirt XML
[here](/2013-06-11/guest.xml) .\
\
Until Next Time,\
Dusty\
\
**NOTE:** An easy way to tell if trim operations are supported in the
guest is to cat out the /sys/block/sda/queue/discard\_\* files. On my
system that supports trim operations it looks like:\
\

```nohighlight
[root@guest ~]# cat /sys/block/sda/queue/discard_*
4096
4294966784
0
```

\
**TRIM/SSD Reference Material:**\
<https://patrick-nagel.net/blog/archives/337>\
<http://www.linux-kvm.org/wiki/images/7/77/2012-forum-thin-provisioning.pdf>\
<http://www.outflux.net/blog/archives/2012/02/15/discard-hole-punching-and-trim/>\

