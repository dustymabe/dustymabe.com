---
title: "RPM File Colors"
tags:
date: "2013-08-25"
draft: false
---

#### *What are RPM file colors?*

\
When building a package `rpm` will tag each file within the package with
a file color. Usually the file color will fit into one of four
categories as described by Jeff Johnson
[here.](http://www.redhat.com/archives/rpm-list/2003-May/msg00228.html)
These categories are:\

-   0 is unknown or other
-   1 is Elf32
-   2 is Elf64
-   3 is (contains) both

So why does `rpm` do this? The short answer is "for multilib support".
Basically so we can install both the 32bit and 64bit version of a
package on the system and have some hopes of everything still working
correctly.\
\
An example of this would be a system that needed both the 32bit and
64bit version of `glibc` (chances are you have them both installed
because some package has been slow to move to 64bit and only provides
software compiled for 32bit). The problem with having both rpms
installed is that both rpms provide some of the same files (i.e
`/sbin/ldconfig`). Which one should rpm choose? This is where file
colors come in.\
\
When installing a file from a new package `rpm` will check to see if the
file is already provided by another rpm and will then use file color to
determine if the file should be replaced or left alone. The current
behavior of `rpm` is to prefer 64bit over 32bit files. That means when
both i686 and x86\_64 `glibc` are installed, `ldconfig` should be 64bit.
This can easily be checked:\
\

```nohighlight
[root@Cent64 ~]# rpm -q glibc
glibc-2.12-1.107.el6_4.2.x86_64
[root@Cent64 ~]# rpm -q --filecolor glibc | grep /sbin/ldconfig
/sbin/ldconfig  2
[root@Cent64 ~]# rpm -ivvh glibc-*.i686.rpm nss-softokn-freebl-*.i686.rpm
...
D: fini      100755  1 (   0,   0)    787476 /sbin/ldconfig;521a4bd1 skipcolor
...
[root@Cent64 ~]# rpm -qs glibc-2.12-1.107.el6_4.2.x86_64 | grep /sbin/ldconfig
normal        /sbin/ldconfig
[root@Cent64 ~]# rpm -qs glibc-2.12-1.107.el6_4.2.i686 | grep /sbin/ldconfig
wrong color   /sbin/ldconfig
[root@Cent64 ~]# file /sbin/ldconfig 
/sbin/ldconfig: ELF 64-bit LSB executable,...
```

\
As expected the 64bit `ldconfig` was left in place as denoted by
`skipcolor` in the output. It is also shown when querying the state of
the i686 `glibc` that `/sbin/ldconfig` has the "wrong color".

#### *RPM file colors gone bad.*

\
Yes, file colors are a nice hack (that takes place in the background) to
make multilib work. Most of the time it works just fine and the user is
none the wiser. However, sometimes there are nasty little complexities
that this can introduce.\
\
HP provides the `hp-health` rpm to help monitor HP hardware. In
[hp-health-8.6.2.2-14.rhel6.x86\_64.rpm](http://downloads.linux.hp.com/downloads/PSP/RedHatEnterpriseServer/6.0/packages/x86_64/hp-health-8.6.2.2-14.rhel6.x86_64.rpm)
`/sbin/hpasmcli` was 32bit. In
[hp-health-9.1.0.42-54.rhel6.x86\_64.rpm](http://downloads.linux.hp.com/downloads/PSP/RedHatEnterpriseServer/6.0/packages/x86_64/hp-health-9.1.0.42-54.rhel6.x86_64.rpm)
`/sbin/hpasmcli` had changed to 64bit. This can be seen by querying the
rpms:\
\

```nohighlight
[root@Cent64 ~]# rpm -qp --filecolor hp-health-8.6.2.2-14.rhel6.x86_64.rpm | grep /sbin/hpasmcli
/sbin/hpasmcli  1
[root@Cent64 ~]# rpm -qp --filecolor hp-health-9.1.0.42-54.rhel6.x86_64.rpm | grep /sbin/hpasmcli
/sbin/hpasmcli  2
```

\
Upgrading from the older rpm to the newer rpm has the expected
behavior:\
\

```nohighlight
[root@Cent64 ~]# rpm -i hp-health-8.6.2.2-14.rhel6.x86_64.rpm &>/dev/null
[root@Cent64 ~]# file /sbin/hpasmcli 
/sbin/hpasmcli: ELF 32-bit LSB executable,...
[root@Cent64 ~]# rpm -U hp-health-9.1.0.42-54.rhel6.x86_64.rpm &>/dev/null
[root@Cent64 ~]# file /sbin/hpasmcli 
/sbin/hpasmcli: ELF 64-bit LSB executable,...
```

\
The problem comes in, however, when you try to go the other way. I know
its not that common but sometimes I do "upgrade" to the older version of
a package:\
\

```nohighlight
[root@Cent64 ~]# rpm -Uvv --oldpackage hp-health-8.6.2.2-14.rhel6.x86_64.rpm
...
D: fini      100755  1 (   0,   0)    179005 /sbin/hpasmcli;521a55ec skipcolor
...
[root@Cent64 ~]# file /sbin/hpasmcli 
/sbin/hpasmcli: ELF 64-bit LSB executable,...
[root@Cent64 ~]# rpm -qs hp-health | grep /sbin/hpasmcli
wrong color   /sbin/hpasmcli
```

\
Basically what happened here is the 64bit version of `hpasmcli` was left
in place. This was not what I expected when I originally did the
"downgrade" and was caused by the subtle behavior of file colors within
`rpm`. The workaround for this is to just fully uninstall and reinstall
the version that you desire.\
\
Dusty
