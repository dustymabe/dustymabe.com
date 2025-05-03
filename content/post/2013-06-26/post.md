---
title: "Enabling QEMU Guest Agent anddddd FSTRIM (AGAIN)"
tags:
date: "2013-06-26"
draft: false
---

In an earlier post I walked through [reclaiming disk space from guests
using
FSTRIM](/2013/06/11/recover-space-from-vm-disk-images-by-using-discardfstrim/)
and in a follow up I showed how to do the same thing with [thin Logical
Volumes](/2013/06/21/guest-discardfstrim-on-thin-lvs/) as the sparse
backing storage for the disk images. In both of the previous posts I
logged in to the guest first and then executed the `fstrim` command in
order to release the free blocks back to the underlying block devices.\
\
Thankfully, due to some [recent
work,](http://git.qemu.org/?p=qemu.git;a=commit;h=eab5fd5989a1ac48d123ccaec7346ce325b9ee77)
this operation has now been exposed externally via [qemu Guest
Agent](http://wiki.qemu.org/Features/QAPI/GuestAgent) and can be
executed remotely via
[libvirt.](http://wiki.libvirt.org/page/Qemu_guest_agent) To enable qemu
Guest Agent, first I added a virtio-serial device that the host and
guest will use for communication. I did this by adding the following to
the guest's xml:\
\

```nohighlight
<channel type='unix'>
  <source mode='bind' path='/var/lib/libvirt/qemu/Fedora19.agent'/>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
```

\
After a power cycle of the guest I added the qemu-guest-agent rpm inside
of my guest. Then I started the qemu-guest-agent service using
`systemctl` as shown below:\
\

```nohighlight
[root@guest ~]# yum install qemu-guest-agent
...
Installed:
  qemu-guest-agent.x86_64 2:1.4.2-2.fc19                                                                    

Complete!

[root@guest ~]# systemctl start qemu-guest-agent.service
[root@guest ~]# systemctl status qemu-guest-agent.service
qemu-guest-agent.service - QEMU Guest Agent
   Loaded: loaded (/usr/lib/systemd/system/qemu-guest-agent.service; static)
   Active: active (running) since Sun 2013-06-02 16:38:18 EDT; 6s ago
 Main PID: 913 (qemu-ga)
   CGroup: name=systemd:/system/qemu-guest-agent.service
           └─913 /usr/bin/qemu-ga
```

\
Finally I could test out the fstrim functionality (again)! In the host I
copied the file into the guest.\
\

```nohighlight
[root@host ~]# du -sh /guests/Fedora19.img 
1.3G    /guests/Fedora19.img
[root@host ~]# 
[root@host ~]# scp /tmp/code.tar.gz root@192.168.100.136:/root/
root@192.168.100.136's password: 
code.tar.gz                                                   100% 1134MB  81.0MB/s   00:14    
[root@host ~]# du -sh /guests/Fedora19.img 
2.4G    /guests/Fedora19.img
```

\
Then, inside the guest I deleted the file:\
\

```nohighlight
[root@guest ~]# rm /root/code.tar.gz 
rm: remove regular file ‘/root/code.tar.gz’? y
```

\
And finally I can remotely execute the `guest-fstrim` command via
`virsh`:\
\

```nohighlight
[root@host ~]# 
[root@host ~]# virsh qemu-agent-command Fedora19 '{"execute":"guest-fstrim"}'
{"return":{}}

[root@host ~]# du -sh /guests/Fedora19.img 
1.3G    /guests/Fedora19.img
```

\
This is powerful stuff because I can now remotely (via libvirt) direct
all of my guests, whether there be 5 or 5000, to all give back free
space to underlying sparse storage devices.\
\
The full guest libvirt XML from this post can be found
[here.](/2013-06-26/guest.xml)\
\
Hope everyone is having a great summer!\
\
Dusty
