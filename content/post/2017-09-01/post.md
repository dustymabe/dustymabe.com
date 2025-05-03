---
title: 'Atomic Host 101 Lab Part 3: Rebase, Upgrade, Rollback'
author: dustymabe
date: 2017-09-01
tags: [ fedora, atomic ]
draft: false
---

# Introduction

In [Part 2](/2017/08/31/atomic-host-101-lab-part-2-container-storage/)
of this series we learned about configuring container storage
on Atomic Host. In this section we will cover the following topics
from the outline in [Part 0](/2017/08/29/atomic-host-101-lab-part-0-preparation/).

- Atomic Host Rebasing 
- Atomic Host Upgrades and Rollbacks
- Browsing OS History

# Rebasing

One of the more fascinating aspects of Atomic Host techology is that
you can rebase to completely different operating system trees.
Let's take this to an extreme and go from the newer technology in
Fedora to the older (more stable) technology in CentOS. We'll achieve
by rebasing to an OSTree commit that was built from CentOS 7 RPMs:

```nohighlight
[root@localhost ~]# rpm-ostree rebase local:centos-atomic-host/7/x86_64/standard

1908 metadata, 14284 content objects fetched; 414666 KiB transferred in 84 seconds
Copying /etc changes: 23 modified, 0 removed, 63 added
Transaction complete; bootconfig swap: yes deployment count change: 1
...
  kernel 4.12.5-300.fc26 -> 3.10.0-514.26.2.el7
...
Run "systemctl reboot" to start a reboot
[root@localhost ~]# reboot
```

For brevity the output from the command was truncated, but you can see
that the kernel went from `kernel-4.12.5-300.fc26` to `kernel-3.10.0-514.26.2.el7`
as part of the transition to CentOS.

After the reboot we can log back in and inspect the system:

```nohighlight
$ vagrant ssh
Last login: Mon Aug 28 00:37:32 2017 from 192.168.121.1
Fedora Atomic Host is Awesome!
[vagrant@localhost ~]$ 
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# cat /etc/redhat-release 
CentOS Linux release 7.3.1611 (Core) 
[root@localhost ~]# 
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● local:centos-atomic-host/7/x86_64/standard
             Version: 7.1707 (2017-07-31 16:12:06)
              Commit: 0bf6200211dd4fd63be6e9bc5c90bea645e2696c0117b05f83562081813a5b94

  local:fedora/26/x86_64/updates/atomic-host
             Version: 26.110 (2017-08-20 18:10:09)
              Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
```

**NOTE:** *The ● indicates the currently booted deployment and the order of the
          status output indicates the boot priority order.*

It's pretty amazing that we effectively switched our entire OS from
Fedora 26 to CentOS 7. One of the first things to notice in the output
above is that the MOTD `Fedora Atomic Host is Awesome!` is now wrong. Let's 
update it to mention CentOS:

```nohighlight
[root@localhost ~]# echo 'CentOS Atomic Host is Awesome!' > /etc/motd
[root@localhost ~]# exit
logout
[vagrant@localhost ~]$ exit
logout
Connection to 192.168.121.57 closed.
[user@laptop ~]$ vagrant ssh
Last login: Mon Aug 28 01:09:18 2017 from 192.168.121.1
CentOS Atomic Host is Awesome!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# 
```

Now that we have that settled, let's poke around to see what else is awry:

```nohighlight
[root@localhost ~]# systemctl --failed | head -n 4
  UNIT             LOAD   ACTIVE SUB    DESCRIPTION
● kdump.service    loaded failed failed Crash recovery kernel arming
● localweb.service loaded failed failed localweb.service
```

Any guesses as to why `localweb.service` failed to start? Here's a
hint: *Python 3*.

Fedora includes Python 3 by default where CentOS doesn't have it included.
Our service is using Python 3 and a Python 3 only module. We need to fix it
by replacing `python3 -m http.server` with `python -m SimpleHTTPServer`.

```nohighlight
[root@localhost ~]# sed -i 's|/usr/bin/python3 -m http.server|/usr/bin/python -m SimpleHTTPServer|'  /etc/systemd/system/localweb.service
[root@localhost ~]# systemctl daemon-reload && systemctl start localweb
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

Now that we have the `localweb` service fixed, let's check our container
runtime to see if it is running:

```nohighlight
[root@localhost ~]# docker info | grep 'Storage Driver' 
Storage Driver: devicemapper
[root@localhost ~]# docker images
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
registry.fedoraproject.org/f25/httpd   latest              a16c8800bb14        3 days ago          648.7 MB
[root@localhost ~]# docker ps -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
b0509ea6c6b6        a16c8800bb14        "sleep 600"         16 minutes ago      Exited (0) 6 minutes ago                       vibrant_lalande
```

Looks good. The docker daemon is still using devicemapper as the storage backend
and the image we imported in Part 2 is still there. We can even see the 
*Exited* container we started before we did the rebase.


# Rollback

While this trip to neverland (rebasing Fedora 26 to CentOS 7) was a fun exercise
let's head back to where we were before we started this adventure. First let's
review the changes we made to the system since we rebased:

- we've updated `/etc/motd`
- we've fixed the `localweb.service` systemd unit to use Python 2

At this point we can actually see the diff in these files between the old 
deployment and the current deployment: 

```nohighlight
[root@localhost ~]# diff -ur /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/etc/motd /etc/motd
--- /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/etc/motd     2017-08-28 00:37:01.003412786 +0000
+++ /etc/motd   2017-08-28 01:11:51.099930383 +0000
@@ -1 +1 @@
-Fedora Atomic Host is Awesome!
+CentOS Atomic Host is Awesome!
```

```nohighlight
[root@localhost ~]# diff -ur /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/etc/systemd/system/localweb.service /etc/systemd/system/localweb.service
--- /ostree/deploy/fedora-atomic/deploy/13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0/etc/systemd/system/localweb.service  2017-08-28 00:24:57.228412786 +0000
+++ /etc/systemd/system/localweb.service        2017-08-28 01:14:12.367930383 +0000
@@ -2,7 +2,7 @@
 
 [Service]
 WorkingDirectory=/srv/localweb
-ExecStart=/usr/bin/python3 -m http.server
+ExecStart=/usr/bin/python -m SimpleHTTPServer
 
 [Install]
 WantedBy=multi-user.target
```

Keep these changes in mind as we do the rollback to Fedora 26 Atomic
Host.

Let's do the rollback now:

```nohighlight
[root@localhost ~]# rpm-ostree rollback --reboot 
Moving '13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424.0' to be first deployment
Transaction complete; bootconfig swap: yes deployment count change: 0
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.
```


After the rollback/reboot we can log back in and inspect the machine:

```nohighlight
$ vagrant ssh 
Last login: Mon Aug 28 01:12:04 2017 from 192.168.121.1
Fedora Atomic Host is Awesome!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]#
```

The first thing you will notice is that the `Fedora Atomic Host is Awesome!`
MOTD has been restored to the pre-rebase state of the system. In fact, all of the
configuration changes in `/etc` have been reverted.

Let's check the other file that we had changed that should have been reverted:

```nohighlight
[root@localhost ~]# systemctl cat localweb.service
# /etc/systemd/system/localweb.service
[Unit]

[Service]
WorkingDirectory=/srv/localweb
ExecStart=/usr/bin/python3 -m http.server

[Install]
WantedBy=multi-user.target
```

As expected, we're back to using Python 3. Is the localweb service working?

```nohighlight
[root@localhost ~]# systemctl status localweb
● localweb.service
   Loaded: loaded (/etc/systemd/system/localweb.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2017-08-28 01:23:25 UTC; 1min 51s ago
 Main PID: 669 (python3)
    Tasks: 1 (limit: 4915)
   Memory: 19.2M
      CPU: 332ms
   CGroup: /system.slice/localweb.service
           └─669 /usr/bin/python3 -m http.server

Aug 28 01:23:25 localhost.localdomain systemd[1]: Started localweb.service.
[root@localhost ~]#
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

Looks good!

This means we have rolled back fully to our pre-upgrade state
The status output shows we are back to fedora as our booted deployment:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.110 (2017-08-20 18:10:09)
                    Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424

  local:centos-atomic-host/7/x86_64/standard
                   Version: 7.1707 (2017-07-31 16:12:06)
                    Commit: 0bf6200211dd4fd63be6e9bc5c90bea645e2696c0117b05f83562081813a5b94
```

# Upgrade

Instead of rebasing to CentOS, like we did earlier, what would have been a more normal
thing to do? Most likely just checking to see if an upgrade existing for our existing 
Fedora 26 ref we are following. Let's do that now:

```nohighlight
[root@localhost ~]# rpm-ostree upgrade 

810 metadata, 3678 content objects fetched; 174260 KiB transferred in 21 seconds                                                                                                                                  
Copying /etc changes: 23 modified, 4 removed, 70 added
Transaction complete; bootconfig swap: yes deployment count change: 0
Freed objects: 24.8 MB
Freed pkgcache branches: 1 size: 246.6 kB
Upgraded:
  bind99-libs 9.9.10-1.P2.fc26 -> 9.9.10-2.P3.fc26
  bind99-license 9.9.10-1.P2.fc26 -> 9.9.10-2.P3.fc26
  ca-certificates 2017.2.14-1.0.fc26 -> 2017.2.16-1.0.fc26
  coreutils 8.27-5.fc26 -> 8.27-6.fc26
  coreutils-common 8.27-5.fc26 -> 8.27-6.fc26
  expat 2.2.3-1.fc26 -> 2.2.4-1.fc26
  file 5.30-9.fc26 -> 5.30-10.fc26
  file-libs 5.30-9.fc26 -> 5.30-10.fc26
  glibc 2.25-8.fc26 -> 2.25-9.fc26
  glibc-all-langpacks 2.25-8.fc26 -> 2.25-9.fc26
  glibc-common 2.25-8.fc26 -> 2.25-9.fc26
  kernel 4.12.5-300.fc26 -> 4.12.8-300.fc26
  kernel-core 4.12.5-300.fc26 -> 4.12.8-300.fc26
  kernel-modules 4.12.5-300.fc26 -> 4.12.8-300.fc26
  libcrypt-nss 2.25-8.fc26 -> 2.25-9.fc26
  librepo 1.7.20-3.fc26 -> 1.8.0-1.fc26
  lz4-libs 1.7.5-4.fc26 -> 1.8.0-1.fc26
  nspr 4.15.0-1.fc26 -> 4.16.0-1.fc26
  nss 3.31.0-1.1.fc26 -> 3.32.0-1.1.fc26
  nss-softokn 3.31.0-1.0.fc26 -> 3.32.0-1.2.fc26
  nss-softokn-freebl 3.31.0-1.0.fc26 -> 3.32.0-1.2.fc26
  nss-sysinit 3.31.0-1.1.fc26 -> 3.32.0-1.1.fc26
  nss-tools 3.31.0-1.1.fc26 -> 3.32.0-1.1.fc26
  nss-util 3.31.0-1.0.fc26 -> 3.32.0-1.0.fc26
  oci-umount 2:1.13.1-21.git27e468e.fc26 -> 2:2.0.0-2.gitf90b64c.fc26
  ostree 2017.9-2.fc26 -> 2017.10-2.fc26
  ostree-grub2 2017.9-2.fc26 -> 2017.10-2.fc26
  ostree-libs 2017.9-2.fc26 -> 2017.10-2.fc26
  p11-kit 0.23.5-3.fc26 -> 0.23.8-1.fc26
  p11-kit-trust 0.23.5-3.fc26 -> 0.23.8-1.fc26
  python3-rpm 4.13.0.1-5.fc26 -> 4.13.0.1-7.fc26
  rpm 4.13.0.1-5.fc26 -> 4.13.0.1-7.fc26
  rpm-build-libs 4.13.0.1-5.fc26 -> 4.13.0.1-7.fc26
  rpm-libs 4.13.0.1-5.fc26 -> 4.13.0.1-7.fc26
  rpm-ostree 2017.7-1.fc26 -> 2017.8-2.fc26
  rpm-plugin-selinux 4.13.0.1-5.fc26 -> 4.13.0.1-7.fc26
  sqlite-libs 3.20.0-1.fc26 -> 3.20.0-2.fc26
  vim-minimal 2:8.0.946-1.fc26 -> 2:8.0.983-1.fc26
Added:
  rpm-ostree-libs-2017.8-2.fc26.x86_64
Run "systemctl reboot" to start a reboot
[root@localhost ~]# reboot 
```

So there was an upgrade for the ref we were following and about 40
packages were updated and we even had a package that was added to
the base OSTree.

What does the system look like after the reboot?


```nohighlight
$ vagrant ssh 
Last login: Mon Aug 28 02:05:28 2017 from 192.168.121.1
Fedora Atomic Host is Awesome!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# 
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                    Commit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5

  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.110 (2017-08-20 18:10:09)
                    Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
```

We can see that we have upgraded from version `26.110` to `26.115`
of the OSTree.


# Browsing histroy

The nice thing about OSTree being *"Like Git For Your OS"* is that you can 
browse the history. What happened in the commits between `26.110` and
`26.115`? Let's find out: 

```nohighlight
[root@localhost ~]# rpm-ostree db diff 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424 a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5 
ostree diff commit old: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
Upgraded:
  bind99-libs 9.9.10-1.P2.fc26.x86_64 -> 9.9.10-2.P3.fc26.x86_64
  bind99-license 9.9.10-1.P2.fc26.noarch -> 9.9.10-2.P3.fc26.noarch
  ca-certificates 2017.2.14-1.0.fc26.noarch -> 2017.2.16-1.0.fc26.noarch
  coreutils 8.27-5.fc26.x86_64 -> 8.27-6.fc26.x86_64
  coreutils-common 8.27-5.fc26.x86_64 -> 8.27-6.fc26.x86_64
  expat 2.2.3-1.fc26.x86_64 -> 2.2.4-1.fc26.x86_64
  file 5.30-9.fc26.x86_64 -> 5.30-10.fc26.x86_64
  file-libs 5.30-9.fc26.x86_64 -> 5.30-10.fc26.x86_64
  glibc 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  glibc-all-langpacks 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  glibc-common 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  kernel 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  kernel-core 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  kernel-modules 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  libcrypt-nss 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  librepo 1.7.20-3.fc26.x86_64 -> 1.8.0-1.fc26.x86_64
  lz4-libs 1.7.5-4.fc26.x86_64 -> 1.8.0-1.fc26.x86_64
  nspr 4.15.0-1.fc26.x86_64 -> 4.16.0-1.fc26.x86_64
  nss 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-softokn 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.2.fc26.x86_64
  nss-softokn-freebl 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.2.fc26.x86_64
  nss-sysinit 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-tools 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-util 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.0.fc26.x86_64
  oci-umount 2:1.13.1-21.git27e468e.fc26.x86_64 -> 2:2.0.0-2.gitf90b64c.fc26.x86_64
  ostree 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  ostree-grub2 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  ostree-libs 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  p11-kit 0.23.5-3.fc26.x86_64 -> 0.23.8-1.fc26.x86_64
  p11-kit-trust 0.23.5-3.fc26.x86_64 -> 0.23.8-1.fc26.x86_64
  python3-rpm 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-build-libs 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-libs 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-ostree 2017.7-1.fc26.x86_64 -> 2017.8-2.fc26.x86_64
  rpm-plugin-selinux 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  sqlite-libs 3.20.0-1.fc26.x86_64 -> 3.20.0-2.fc26.x86_64
  vim-minimal 2:8.0.946-1.fc26.x86_64 -> 2:8.0.983-1.fc26.x86_64
Added:
  rpm-ostree-libs-2017.8-2.fc26.x86_64
```

The `rpm-ostree db diff` output is the same as the output that gets
printed when you originally perform an upgrade or rebase. Even more
useful, is being able to look at each one of the commits between
`26.110` and `26.115` and see exactly what changed in each of
them. While it's not the easiest thing to do to browse this history
the information is there so we just have to get to it.

The first step is to get the information about each commit onto the
system. You can do this by pulling the commit metadata and the RPM
database from each of the commits:

```nohighlight
[root@localhost ~]# ostree pull --commit-metadata-only --depth=-1 local:fedora/26/x86_64/updates/atomic-host

22 metadata, 0 content objects fetched; 9 KiB transferred in 0 seconds
[root@localhost ~]# 
[root@localhost ~]# ostree pull --subpath /usr/share/rpm --depth=-1 local:fedora/26/x86_64/updates/atomic-host

50 metadata, 171 content objects fetched; 67823 KiB transferred in 8 seconds
```

**NOTE:** * The `--depth=-1` implies to grab all history.

We just pulled the commit metadata from each commit in the history
of the `fedora/26/x86_64/updates/atomic-host` ref. How do we now 
view the diff between each commit in the history? One method is
to script inputs to `rpm-ostree db diff`.

To do this, we'll set a variable `old=''` and 
`commit=a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5`,
which is the commit related to `26.115`. Then we'll iteratively call
`rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'`
to iterate over the commits until we get to the `26.110` commit.

Let's see how it works:

```nohighlight
[root@localhost ~]# old=''
[root@localhost ~]# commit='a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5'
[root@localhost ~]# 
[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'
ostree diff commit old: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^ (59bc8e66abe22c4338aecbd300b5343f0e44537204496dc25f0541b079b28b4d)
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
Upgraded:
  librepo 1.7.20-3.fc26.x86_64 -> 1.8.0-1.fc26.x86_64
  oci-umount 2:1.13.1-21.git27e468e.fc26.x86_64 -> 2:2.0.0-2.gitf90b64c.fc26.x86_64
  python3-rpm 4.13.0.1-6.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm 4.13.0.1-6.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-build-libs 4.13.0.1-6.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-libs 4.13.0.1-6.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
  rpm-plugin-selinux 4.13.0.1-6.fc26.x86_64 -> 4.13.0.1-7.fc26.x86_64
                    
                    
[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'
ostree diff commit old: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^ (7c1f406901ef991dd556b1a69b008f63346f4fcf831dccdf9cb115c76385a246)
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^ (59bc8e66abe22c4338aecbd300b5343f0e44537204496dc25f0541b079b28b4d)
Upgraded:
  bind99-libs 9.9.10-1.P2.fc26.x86_64 -> 9.9.10-2.P3.fc26.x86_64
  bind99-license 9.9.10-1.P2.fc26.noarch -> 9.9.10-2.P3.fc26.noarch
  expat 2.2.3-1.fc26.x86_64 -> 2.2.4-1.fc26.x86_64
  p11-kit 0.23.5-3.fc26.x86_64 -> 0.23.8-1.fc26.x86_64
  p11-kit-trust 0.23.5-3.fc26.x86_64 -> 0.23.8-1.fc26.x86_64
  sqlite-libs 3.20.0-1.fc26.x86_64 -> 3.20.0-2.fc26.x86_64
                    
                    
[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'
ostree diff commit old: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^^ (4c57eeb2478c6a0a4c41c3ec2fa900e8258725a84cc3e87f510ce271c1774dc6)
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^ (7c1f406901ef991dd556b1a69b008f63346f4fcf831dccdf9cb115c76385a246)
Upgraded:
  coreutils 8.27-5.fc26.x86_64 -> 8.27-6.fc26.x86_64
  coreutils-common 8.27-5.fc26.x86_64 -> 8.27-6.fc26.x86_64
  kernel 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  kernel-core 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  kernel-modules 4.12.5-300.fc26.x86_64 -> 4.12.8-300.fc26.x86_64
  nspr 4.15.0-1.fc26.x86_64 -> 4.16.0-1.fc26.x86_64
  nss 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-softokn 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.2.fc26.x86_64
  nss-softokn-freebl 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.2.fc26.x86_64
  nss-sysinit 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-tools 3.31.0-1.1.fc26.x86_64 -> 3.32.0-1.1.fc26.x86_64
  nss-util 3.31.0-1.0.fc26.x86_64 -> 3.32.0-1.0.fc26.x86_64
  ostree 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  ostree-grub2 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  ostree-libs 2017.9-2.fc26.x86_64 -> 2017.10-2.fc26.x86_64
  rpm-ostree 2017.7-1.fc26.x86_64 -> 2017.8-2.fc26.x86_64
  vim-minimal 2:8.0.946-1.fc26.x86_64 -> 2:8.0.983-1.fc26.x86_64
Added:
  rpm-ostree-libs-2017.8-2.fc26.x86_64
                    
                    
^[[A[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+^C
[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'
ostree diff commit old: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^^^ (55be41d9a8f5b7d774652aa4a4d407d496b8892d3d51a6585e6ee268940677ad)
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^^ (4c57eeb2478c6a0a4c41c3ec2fa900e8258725a84cc3e87f510ce271c1774dc6)
Upgraded:
  ca-certificates 2017.2.14-1.0.fc26.noarch -> 2017.2.16-1.0.fc26.noarch
  glibc 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  glibc-all-langpacks 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  glibc-common 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  libcrypt-nss 2.25-8.fc26.x86_64 -> 2.25-9.fc26.x86_64
  lz4-libs 1.7.5-4.fc26.x86_64 -> 1.8.0-1.fc26.x86_64
  python3-rpm 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-6.fc26.x86_64
  rpm 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-6.fc26.x86_64
  rpm-build-libs 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-6.fc26.x86_64
  rpm-libs 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-6.fc26.x86_64
  rpm-plugin-selinux 4.13.0.1-5.fc26.x86_64 -> 4.13.0.1-6.fc26.x86_64
                    
                    
[root@localhost ~]# rpm-ostree db diff "${commit}${old}^" "${commit}${old}"; old+='^'
ostree diff commit old: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^^^^ (13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424)
ostree diff commit new: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5^^^^ (55be41d9a8f5b7d774652aa4a4d407d496b8892d3d51a6585e6ee268940677ad)
Upgraded:
  file 5.30-9.fc26.x86_64 -> 5.30-10.fc26.x86_64
  file-libs 5.30-9.fc26.x86_64 -> 5.30-10.fc26.x86_64
```

This is extremely useful granualar knowledge that can be used for
testing/reproducibility purposes. Any one of these commits can be 
deployed and tested using the `rpm-ostree deploy` command in order
to find an exact change that caused a bug to be introduced.

# Part 3 Wrap Up

Part 3 of this lab has included rebasing from Fedora 26 to CentOS 7,
rolling that back, and then upgrading to a newer version of Fedora 26.
After the 26 upgrade we looked specifically at each commit in the
difference between the pre-upgrade version and post-upgrade version.

In the [next lab](/2017/09/02/atomic-host-101-lab-part-4-package-layering-experimental-features/)
we'll cover RPM package layering and also new experimental features of rpm-ostree.

