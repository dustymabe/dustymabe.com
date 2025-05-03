---
title: "Nested Virt and Fedora 20 Virt Test Day"
tags:
date: "2013-10-21"
draft: false
---

#### *Introduction*

\
I decided this year to take part in the [Fedora Virtualization Test
Day](https://fedoraproject.org/wiki/Test_Day:2013-10-08_Virtualization)
on October 8th. In order to take part I needed a system with Fedora 20
installed so that I could then create VMs on top. Since I like my
current setup and I didn't have a hard drive laying around that I wanted
to wipe I decided to give nested virtualization a shot.\
\
Most of the documentation I have seen for nested virtualization has come
from [Kashyap Chamarthy](http://kashyapc.wordpress.com/). Relevant posts
are
[here,](https://github.com/kashyapc/nvmx-haswell/blob/master/SETUP-nVMX.rst)
[here,](http://kashyapc.wordpress.com/2013/02/12/nested-virtualization-with-kvm-and-intel-on-fedora-18/)
and
[here.](http://kashyapc.wordpress.com/2012/01/14/nested-virtualization-with-kvm-intel/)
He has done a great job with these tutorials and this post is nothing
more than my notes for what I found to work for me.

#### *Steps*

\
With nested virtualization the OS/Hypervisor that touches the physical
hardware is known as L0. The first level of virtualized guest is known
as L1. The second level of virtualized guest (the guest inside a guest)
is known as L2. In my setup I ultimately wanted F19(L0), F20(L1), and
F20(L2).\
\
First, in order to pass along intel vmx extensions to the guest I
created a modprobe config file that instructs the kvm\_intel kernel
module to allow nested virtualization support:\
\

```nohighlight
[root@L0 ~]# echo "options kvm-intel nested=y" > /etc/modprobe.d/nestvirt.conf
```

\
After a reboot I can now confirm the kvm_intel module is configured for
nested virt:\
\

```nohighlight
[root@L0 ~]# cat /sys/module/kvm_intel/parameters/nested
Y
```

\
Next I converted an existing Fedora 20 installation to use
"host-passthrough" (see
[here](http://libvirt.org/formatdomain.html#elementsCPU)) so that the L1
guest would see the same processor (with vmx extensions) as my L0 host.
To do this i modified the cpu xml tags as follows in the libvirt xml
definition:\
\

```nohighlight
  <cpu mode='host-passthrough'>
  </cpu>
```

\
After powering up the guest I now see that the processor that the L1
guest sees is indeed the same as the host:

```nohighlight
[root@L1 ~]# cat /proc/cpuinfo | grep "model name"
model name      : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
model name      : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
model name      : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
model name      : Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz
```

\
Next I decided to enable nested virt in the L1 guest by adding the same
modprobe.conf file as I did in L0. I did this based on a tip from
Kashyap in the \#fedora-test-day chat that this tends to give about a
10X performance improvement in the L2 guests.\
\

```nohighlight
[root@L1 ~]# echo "options kvm-intel nested=y" > /etc/modprobe.d/nestvirt.conf
```

\
After a reboot I could then create and install L2 guests using
virt-install and virt-manager. This seemed to work fine except for the
fact that I would often see an unknown NMI in the guest periodically.\
\

```nohighlight
[   14.324786] Uhhuh. NMI received for unknown reason 30 on CPU 0.
[   14.325046] Do you have a strange power saving mode enabled?
[   14.325046] Dazed and confused, but trying to continue
```

\
I believe the issue I was seeing may be documented in kernel
[BZ#58941](https://bugzilla.kernel.org/show_bug.cgi?id=58941). After
asking about it in the chat I was informed that for the best experience
with nested virt I should go to a 3.12 kernel. I decided to leave that
exercise for another day :).\
\
Have a great day!\
\
Dusty
