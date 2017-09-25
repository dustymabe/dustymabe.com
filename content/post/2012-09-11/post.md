---
title: "Share a Folder Between KVM Host and Guest"
tags:
date: "2012-09-11"
published: true
---

I often find myself in situations where I need to share information or
files between a KVM host and KVM guest. With libvirt version 0.8.5 and
newer there is support for mounting a shared folder between a host and
guest. I decided to try this out on my Fedora 17 host, with a Fedora 17
guest.\
\
Using the libvirt
[`<filesystem>`](http://libvirt.org/formatdomain.html#elementsFilesystems)
xml tag I created the following xml that defines a *filesystem* device.\
\

```nohighlight
<filesystem type='mount' accessmode='mapped'>
    <source dir='/tmp/shared'/>
    <target dir='tag'/>
</filesystem>
```


\
Note that target dir is not necessarily a mount point, but rather a
string that is exported to the guest that we will use when mounting in
the guest.\
\
In order to get this xml into the guest I had to use `virsh edit F17`
where F17 is the domain name of my guest. This opens the guest xml in
the VI text editor. I then inserted the xml at the end of the
`<devices>` section of the guest xml, closed VI, and started the
guest.\
\
Once the guest had booted I used the following command to mount the
shared folder in the guest.\
\

```nohighlight
[root@F17 ~]# mount -t 9p -o trans=virtio,version=9p2000.L tag /mnt/shared/
```

\
And voila! I can now access the /tmp/ directory of the host inside of
the guest.\
\
Note: I had some SELinux denials as a result of doing this. If I was
using this as a long term solution I would clean them up, but for now I
just disabled SELinux temporarily by using `sudo setenforce 0` in the
host.\
\
Resources:\
<http://www.linux-kvm.org/page/9p_virtio>\
<http://wiki.qemu.org/Documentation/9psetup>\
<http://libvirt.org/formatdomain.html#elementsFilesystems>\

