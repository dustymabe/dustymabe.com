---
title: 'Atomic Host 101 Lab Part 1: Getting Familiar'
author: dustymabe
date: 2017-08-30
tags: [ fedora, atomic ]
published: true
---

# Introduction

In [Part 0](/2017/08/29/atomic-host-101-lab-part-0-preparation/)
of this series we helped get a Fedora 26 Atomic Host system set up 
for the rest of this lab. In this section we will cover the 
following topics from the outline:

- Getting Familiar With Atomic Host
- Viewing Changes To A Deployed System

# Getting Familiar

Atomic Host is built on top of underlying technology known as OSTree 
and leveraged by an *RPM aware* higher level technology known as rpm-ostree.
rpm-ostree is able to build and deliver OSTrees built out of RPMs.
Once built, an OSTree commit can be installed to a server just like
a traditional OS. New OSTree commits are created by a build system and 
a server can pull down and apply updates, similar to a `git pull`.

An admin can also browse history of a repository, similar to a
`git log` and/or `git diff`. Because of this tree-like nature 
OSTree (and thus Atomic Host) is sometimes described as
*"Like Git For Your Operating System"*.

You can interact with an Atomic Host through the
`rpm-ostree` and `ostree` command line utilities. To check the
status of a system you can execute the `rpm-ostree status` command:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.110 (2017-08-20 18:10:09)
                    Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
```

It is also worth noting that a lot of `rpm-ostree` functionality is conveniently
wrapped by the [Atomic CLI](https://github.com/projectatomic/atomic)
via the `atomic host` subcommand. For example:

```nohighlight
[root@localhost ~]# atomic host status
State: idle
Deployments:
● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.110 (2017-08-20 18:10:09)
                    Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
```

This status output tells us interesting things about the host.
The system is currently deployed from commit `13ed0f2` (version `26.110`)
and is following the `fedora/26/x86_64/updates/atomic-host` ref
from the `local` remote. If you remember back in *Lab Part 0* we created
this remote and set the system to track that ref.


What else does rpm-ostree know about our system? One example is that
for each commit you can see all of the RPMs that were installed in the
tree and delivered with the system:

```nohighlight
[root@localhost ~]# rpm-ostree db list 13ed0f2 | head
ostree commit: 13ed0f2 (13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424)
 GeoIP-1.6.11-1.fc26.x86_64
 GeoIP-GeoLite-data-2017.07-1.fc26.noarch
 NetworkManager-1:1.8.2-1.fc26.x86_64
 NetworkManager-libnm-1:1.8.2-1.fc26.x86_64
 NetworkManager-team-1:1.8.2-1.fc26.x86_64
 acl-2.2.52-15.fc26.x86_64
 atomic-1.18.1-5.fc26.x86_64
 atomic-devmode-0.3.7-1.fc26.noarch
 atomic-registries-1.18.1-5.fc26.x86_64
```

So `rpm-ostree` knows what software is installed on the system, but
what about existing tools that detect what software is installed? 
Good news, `rpm` queries still work:

```nohighlight
[root@localhost ~]# rpm -q kernel
kernel-4.12.5-300.fc26.x86_64
```

However, only read-only operations work when trying to modify RPM
content via traditional tools:

```nohighlight
[root@localhost ~]# rpm -ivh /srv/localweb/yumrepo/htop-2.0.2-2.fc26.x86_64.rpm
warning: /srv/localweb/yumrepo/htop-2.0.2-2.fc26.x86_64.rpm: Header V3 RSA/SHA256 Signature, key ID 64dab85d: NOKEY
error: can't create transaction lock on /var/lib/rpm/.rpm.lock (No such file or directory)
[root@localhost ~]#
[root@localhost ~]# dnf install /srv/localweb/yumrepo/htop-2.0.2-2.fc26.x86_64.rpm
bash: dnf: command not found
```

**NOTE:** Even though you can't install RPMs directly using traditional tools you can
          add RPMs via package layering. More on this in a later post.

Why can't we install RPMs? Mostly because some content on Atomic is
static (read-only) content. Let's look at the filesystem structure:

```nohighlight
[root@localhost ~]# ls -l /
total 18
lrwxrwxrwx.   2 root root    7 Aug 21 09:00 bin -> usr/bin
drwxr-xr-x.   8 root root 1024 Aug 21 09:02 boot
drwxr-xr-x.  19 root root 3380 Aug 28 00:15 dev
drwxr-xr-x.  81 root root 8192 Aug 28 00:23 etc
lrwxrwxrwx.   2 root root    8 Aug 21 09:00 home -> var/home
lrwxrwxrwx.   3 root root    7 Aug 21 09:00 lib -> usr/lib
lrwxrwxrwx.   3 root root    9 Aug 21 09:00 lib64 -> usr/lib64
lrwxrwxrwx.   2 root root    9 Aug 21 09:00 media -> run/media
lrwxrwxrwx.   2 root root    7 Aug 21 09:00 mnt -> var/mnt
lrwxrwxrwx.   2 root root    7 Aug 21 09:00 opt -> var/opt
lrwxrwxrwx.   2 root root   14 Aug 21 09:01 ostree -> sysroot/ostree
dr-xr-xr-x. 114 root root    0 Aug 28 00:15 proc
lrwxrwxrwx.   2 root root   12 Aug 21 09:01 root -> var/roothome
drwxr-xr-x.  35 root root 1080 Aug 28 00:15 run
lrwxrwxrwx.   2 root root    8 Aug 21 09:01 sbin -> usr/sbin
lrwxrwxrwx.   2 root root    7 Aug 21 09:01 srv -> var/srv
dr-xr-xr-x.  13 root root    0 Aug 28 00:15 sys
drwxr-xr-x.  11 root root  112 Aug 21 09:00 sysroot
lrwxrwxrwx.   2 root root   11 Aug 21 09:01 tmp -> sysroot/tmp
drwxr-xr-x.  12 root root  155 Jan  1  1970 usr
drwxr-xr-x.  24 root root 4096 Aug 28 00:15 var
```

A lot of the stateful directories point to `/var`, while a lot
of the non stateful directories point to `/usr`. This is by design
as it is best to separate content that we don't want to ever modify,
with transient or runtime content. Let's test it out:

```nohighlight
[root@localhost ~]# touch /var/foofile
[root@localhost ~]# ls -l /var/foofile
-rw-r--r--. 1 root root 0 Aug 28 00:33 /var/foofile
[root@localhost ~]# touch foo /usr/file
touch: cannot touch '/usr/file': Read-only file system
```

As you can see, for the most part `/var` is read/write and `/usr` is read-only.
Some exceptions for `/usr` are `/usr/local` and `/usr/tmp`:

```nohighlight
[root@localhost ~]# ls -l /usr/local /usr/tmp
lrwxrwxrwx. 2 root root 15 Aug 21 09:01 /usr/local -> ../var/usrlocal
lrwxrwxrwx. 2 root root 10 Aug 21 09:01 /usr/tmp -> ../var/tmp
```

Configuration in `/etc` is also read/write and tracked by rpm-ostree on a
per deployment basis. You can diff between what was delivered with the
OSTree and what exists on the active system:

```nohighlight
[root@localhost ~]# ostree admin config-diff | head
M    machine-id
M    subgid
M    subuid
M    hosts
M    localtime
M    systemd/logind.conf
M    systemd/system/default.target
M    group
M    shadow
M    passwd
...
```

The `M` means Modified. An `A` would mean added, while a `D` would
mean the file had been deleted. Let's play around with one of the files:

```nohighlight
[root@localhost ~]# cat /etc/motd
[root@localhost ~]# ostree admin config-diff | grep motd
```

Looks like there has been no change to `/etc/motd` from what was
delivered with the OSTree. We'll add some state and then check again:

```nohighlight
[root@localhost ~]# echo 'Fedora Atomic Host is Awesome!' >> /etc/motd
[root@localhost ~]# ostree admin config-diff | grep motd
M    motd
```

But what changed? Currently with `ostree admin config-diff` we can only
see if it was modified, added or deleted. We can however dig into the
deployments and see the real diff:

```nohighlight
[root@localhost ~]# diff -ur /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/usr/etc/motd /etc/motd
--- /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/usr/etc/motd 1970-01-01 00:00:00.000000000 +0000
+++ /etc/motd   2017-08-28 00:37:01.003412786 +0000
@@ -0,0 +1 @@
+Fedora Atomic Host is Awesome!
```

Let's log out and log back in to see the new message of the day:

```nohighlight
[root@localhost ~]# exit
logout
[vagrant@localhost ~]$ exit
logout
Connection to 192.168.121.57 closed.
[user@laptop]$ vagrant ssh
Fedora Atomic Host is Awesome!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]#
```

In a following post we'll see that this state is also tracked between the various
deployments on a system and will allow us to roll back to a previous
deployment and also restore the state in `/etc`.

# Part 1 Wrap Up

Part 1 of this lab has familiarized us with Atomic Host, the
underlying technology, and how to interact with it. In the
[next lab](/2017/08/31/atomic-host-101-lab-part-2-container-storage/)
we'll cover container storage on Atomic Host.
