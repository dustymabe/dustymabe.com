---
title: 'Atomic Host 101 Lab Part 4: Package Layering, Experimental Features'
author: dustymabe
date: 2017-09-02
tags: [ fedora, atomic ]
published: true
---

# Introduction

In [Part 3](/2017/09/01/atomic-host-101-lab-part-3-rebase-upgrade-rollback/)
of this series we learned about rebasing, upgrading, and performing
rollbacks on Atomic Host. We also learned how files are restored during
a rollback operation and how to inspect the differences in RPM content
between each commit in the OSTree history of an Atomic Host using the
rpm-ostree command line tool. In this section we will cover the following topics
from the outline in [Part 0](/2017/08/29/atomic-host-101-lab-part-0-preparation/).

- Package Layering
- Experimental Features (livefs, remove, replace)


# Adding Packages to Atomic Host via Package Layering

When Atomic Host was first released we could not change much about the
the delivered software on the system. Over time we developed a system
for layering packages on top of what was provided by the base OSTree
to allow the flexibility needed for those few packages that,
for whatever reason, we may not want to put into a container.

The feature that allows for adding new packages to a system is known
as *package layering*. Layering a package is achieved by executing the
`rpm-ostree install` subcommand. Let's give it a spin by layering in
a popular RPM: `htop`.

```nohighlight
[root@localhost ~]# rpm-ostree install htop 
Checking out tree a8db0b7... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-27 17:54:44
Importing metadata 100%
Resolving dependencies... done
Will download: 1 package (106.1 kB)
  Downloading from localyum: 100%
Importing: 100%
Applying 1 overlay... done
Running pre scripts... 0 done
Running post scripts... 3 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 71 added
Transaction complete; bootconfig swap: yes deployment count change: 0
Added:
  htop-2.0.2-2.fc26.x86_64
Run "systemctl reboot" to start a reboot
```

The operation above added `htop` to a new layer on top of the base layer 
and created a new pending deployment (staged for next boot).
We can see this represented in the `rpm-ostree status` output:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
           LayeredPackages: htop

● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                    Commit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
```

Let's go ahead and reboot and use htop!

```nohighlight
[root@localhost ~]# reboot 
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.
$ vagrant ssh 
Last login: Mon Aug 28 02:08:19 2017 from 192.168.121.1
Fedora Atomic Host is Awesome!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# rpm -q htop
htop-2.0.2-2.fc26.x86_64
[root@localhost ~]# htop -v
htop 2.0.2 - (C) 2004-2017 Hisham Muhammad
Released under the GNU GPL.
[root@localhost ~]# htop
...
```


# Experimental Features: livefs

The added flexibility of package layering is quite nice, but in some
scenarios (such as a cloud environment), the necessary reboot after
you layer a package (required to boot into the new deployment) is quite
prohibitive. To workaround this an experimental feature known as
`livefs` has been introduced.

The idea is that if we are simply *adding* software to the system then
the risk of there processes/daemons that are still running with old
outdated copies of the software in memory won't exist. Thus a live
update is relatively safe. 

Let's give `livefs` a spin with a different RPM: `nano`. We'll first need to
package layer in the RPM just like we did before for `htop`. 

```nohighlight
[root@localhost ~]# rpm-ostree install nano
Checking out tree a8db0b7... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-28 22:07:11

Importing metadata 100%
Resolving dependencies... done
Importing: 100%
Applying 2 overlays... done
Running pre scripts... 0 done
Running post scripts... 4 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 72 added
Transaction complete; bootconfig swap: no deployment count change: 0
Added:
  nano-2.8.4-1.fc26.x86_64
Run "systemctl reboot" to start a reboot
```

Now we can see from the status output that the RPM is staged for the
next boot just like what was done for `htop`: 

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
           LayeredPackages: htop nano

● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
           LayeredPackages: htop
```


However, this time we will tell rpm-ostree that we want to go ahead
and apply the updates to the live running system:

```nohighlight
[root@localhost ~]# rpm-ostree ex livefs 
Diff Analysis: 0e12b24e08407d22b71ac971be12dcb6f32b51f4e4e2962960adce0ba4ad07bd => 887f1d79408575a3b99b5c73674f84c3d69fea9b0e6e0e3617d95e296e0bfc82
Files: modified: 1 removed: 0 added: 145
Packages: modified: 0 removed: 0 added: 1
* Configuration changed in /etc
Preparing new rollback matching currently booted deployment
Copying /etc changes: 23 modified, 4 removed, 72 added
Transaction complete; bootconfig swap: yes deployment count change: 1
Overlaying /usr... done
Copying new config files... 1
```

After this operation is complete we can see that the `nano` rpm has
made it onto the live running system and we can now execute the `nano`
command. We can even use it to edit `/etc/motd`!


```nohighlight
[root@localhost ~]# rpm -q nano
nano-2.8.4-1.fc26.x86_64
[root@localhost ~]# 
[root@localhost ~]# nano /etc/motd 
[root@localhost ~]# cat /etc/motd
Fedora Atomic Host is Awesome! Edited with nano!
```


# Experimental Features: override remove

Another experimental feature of rpm-ostree is the ability to remove
packages that were delivered with the base OSTree. Ideally you'd never
need this functionality, but having the flexibility when needed can 
be very useful.

An example package we can remove from the system that doesn't have any
other dependencies is `strace`. Let's check it out in its current
state on the system:

```nohighlight
[root@vanilla-f26atomic ~]# rpm -q strace
strace-4.18-1.fc26.x86_64
[root@vanilla-f26atomic ~]# ls -l /usr/bin/strace
-rwxr-xr-x. 4 root root 1146968 Jan  1  1970 /usr/bin/strace
```

Now we can remove this base package by executing the `rpm-ostree ex
override remove` command:

```nohighlight
[root@localhost ~]# rpm-ostree ex override remove strace
Checking out tree a8db0b7... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-28 22:07:11

Importing metadata 100%
Resolving dependencies... done
Importing: 100%
Applying 1 override and 2 overlays... done
Running pre scripts... 0 done
Running post scripts... 4 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 72 added
Transaction complete; bootconfig swap: no deployment count change: 0
Removed:
  strace-4.18-1.fc26.x86_64
Added:
  nano-2.8.4-1.fc26.x86_64
Run "systemctl reboot" to start a reboot
```

From the operation output we can see that we removed
`strace-4.18-1.fc26.x86_64`. This is further represented in the status
output:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
                    Commit: c70d813bacf424948986aae8c918c28295c35524237413df7601c93ded480f22
       RemovedBasePackages: strace-4.18-1.fc26.x86_64
           LayeredPackages: htop nano

● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
          BootedBaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
                    Commit: 0e12b24e08407d22b71ac971be12dcb6f32b51f4e4e2962960adce0ba4ad07bd
                LiveCommit: 887f1d79408575a3b99b5c73674f84c3d69fea9b0e6e0e3617d95e296e0bfc82
           LayeredPackages: htop

  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
                    Commit: 0e12b24e08407d22b71ac971be12dcb6f32b51f4e4e2962960adce0ba4ad07bd
           LayeredPackages: htop
```

As you can see we have the next staged deployment as well as the old
deployment and a `LiveCommit` deployment. We have the `LiveCommit`
deployment because we ran `livefs` to immediately get `nano` on our system.
Let's try to `livefs` again:

```nohighlight
[root@localhost ~]# rpm-ostree ex livefs 
Note: Previous overlay: 887f1d79408575a3b99b5c73674f84c3d69fea9b0e6e0e3617d95e296e0bfc82
Diff Analysis: 0e12b24e08407d22b71ac971be12dcb6f32b51f4e4e2962960adce0ba4ad07bd => c70d813bacf424948986aae8c918c28295c35524237413df7601c93ded480f22
Files: modified: 1 removed: 2 added: 145
Packages: modified: 0 removed: 1 added: 1
* Configuration changed in /etc
error: livefs update modifies/replaces packages
```

As mentioned before, we can see that the tools won't let you apply
live updates if the update would remove or modify existing software
on the system. This is indicated by the `error: livefs update
modifies/replaces packages` message.

Let's reboot to get to our newly staged deployment with a removed
`strace` package:

```nohighlight
[root@localhost ~]# reboot 
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.
$ 
$ vagrant ssh 
Last login: Mon Aug 28 02:20:06 2017 from 192.168.121.1

Fedora Atomic Host is Awesome! Edited with nano!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# rpm -q strace
package strace is not installed
```

# Experimental Features: override replace


Another experimental feature of Atomic Host is actually being able to
replace some packages in the delivered BaseCommit. This is useful if
you are debugging a particular problem with Atomic Host and want to 
isolate one package to vary when performing tests.

For example, let's assume that the docker installed on the system 
(`docker-1.13.1-21.git27e468e.fc26`) is buggy and we want to test 
out a new version (`docker-1.13.1-22.gitb5e3294.fc26`). 

First let's bring up a container. This will also give us a chance to
host a service in a container, which is a primary target use case and
much preferred method of running applications on top of Atomic Host.

The container image we imported earlier was a Fedora 25 httpd container image. Let's
get rid of the Python based localweb server:

```nohighlight
[root@localhost ~]# systemctl disable --now localweb
Removed /etc/systemd/system/multi-user.target.wants/localweb.service.
[root@localhost ~]# systemctl status localweb
● localweb.service
   Loaded: loaded (/etc/systemd/system/localweb.service; disabled; vendor preset: disabled)
   Active: inactive (dead)

Aug 29 03:35:12 localhost.localdomain systemd[1]: Started localweb.service.
Aug 29 03:39:13 localhost.localdomain systemd[1]: Stopping localweb.service...
Aug 29 03:39:13 localhost.localdomain systemd[1]: Stopped localweb.service.
```

And replace it with the more powerful `httpd` software from within the
container:

```nohighlight
[root@localhost ~]# docker run -d --restart=always --name httpd -p 8000:8080 -v /srv/localweb/:/var/www/html/:Z a16c8800bb14
03fb1de49dd7af4e517827e1b046647b5c1c8f57a1210e63f43f1ac7e922685f
[root@localhost ~]# 
[root@localhost ~]# docker ps 
CONTAINER ID        IMAGE               COMMAND                CREATED              STATUS              PORTS                                               NAMES
03fb1de49dd7        a16c8800bb14        "/usr/bin/run-httpd"   About a minute ago   Up 54 seconds       80/tcp, 443/tcp, 8443/tcp, 0.0.0.0:8000->8080/tcp   httpd
[root@localhost ~]# curl http://localhost:8000/hello.txt                                                
hello world
```

Now, even though the docker service appears to be running fine, let's
pretend there is a bug and things don't work properly. We notice that 
a new version of the docker package exists in the testing repositories and
we want to test it out to see if the new version of the package works. We 
can use `rpm-ostree ex override replace` to achieve this: 

**NOTE:** *We are installing from the docker rpms in `/srv/localweb/yumrepo/`.*

```nohighlight
[root@localhost ~]# rpm-ostree ex override replace /srv/localweb/yumrepo/docker*
Checking out tree a8db0b7... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-28 22:07:11

Importing metadata [==============================================================================] 100%
Resolving dependencies... done
Applying 4 overrides and 2 overlays... done
Running pre scripts... 0 done
Running post scripts... 7 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 72 added
Transaction complete; bootconfig swap: yes deployment count change: -1
Upgraded:
  docker 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26
  docker-common 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26
  docker-rhel-push-plugin 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26
Run "systemctl reboot" to start a reboot
```

The status output again will properly show the changes to the system:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
       RemovedBasePackages: strace-4.18-1.fc26.x86_64
      ReplacedBasePackages: docker-rhel-push-plugin 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26, docker-common 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26, docker 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26
           LayeredPackages: htop nano

● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
       RemovedBasePackages: strace-4.18-1.fc26.x86_64
           LayeredPackages: htop nano
```

After a reboot we can check the new version of docker to see if it is
running just fine:

```nohighlight
[root@localhost ~]# reboot 
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.
$ 
$ 
$ vagrant ssh 
Last login: Mon Aug 28 02:20:06 2017 from 192.168.121.1
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# rpm -q docker
docker-1.13.1-22.gitb5e3294.fc26.x86_64
[root@localhost ~]# docker ps
CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS              PORTS                                               NAMES
03fb1de49dd7        a16c8800bb14        "/usr/bin/run-httpd"   9 minutes ago       Up About a minute   80/tcp, 443/tcp, 8443/tcp, 0.0.0.0:8000->8080/tcp   httpd
[root@localhost ~]# 
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

# Resetting Overridden Base Packages

After making these changes to a system we may want to drop the changes
and get back closer to our base commit that was delivered by OSTree.
In order to do this we can use the `rpm-ostree ex override reset`
command like so:

```nohighlight
[root@localhost ~]# rpm-ostree ex override reset strace docker-rhel-push-plugin docker-common docker
Checking out tree a8db0b7... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-28 22:07:11


Importing metadata [==============================================================================] 100%
Resolving dependencies... done
Applying 2 overlays... done
Running pre scripts... 0 done
Running post scripts... 4 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 73 added
Transaction complete; bootconfig swap: no deployment count change: 0
Downgraded:
  docker 2:1.13.1-22.gitb5e3294.fc26 -> 2:1.13.1-21.git27e468e.fc26
  docker-common 2:1.13.1-22.gitb5e3294.fc26 -> 2:1.13.1-21.git27e468e.fc26
  docker-rhel-push-plugin 2:1.13.1-22.gitb5e3294.fc26 -> 2:1.13.1-21.git27e468e.fc26
Added:
  strace-4.18-1.fc26.x86_64
Run "systemctl reboot" to start a reboot
```

And the status output will show the newly staged deployment with less
*overrides* now:

```nohighlight
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
           LayeredPackages: htop nano

● local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
       RemovedBasePackages: strace-4.18-1.fc26.x86_64
      ReplacedBasePackages: docker-rhel-push-plugin 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26, docker-common 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26, docker 2:1.13.1-21.git27e468e.fc26 -> 2:1.13.1-22.gitb5e3294.fc26
           LayeredPackages: htop nano
```

After a reboot we can see that we no longer have `strace` and that the
`docker` version has been reverted back to what was delivered in the
tree:

```nohighlight
[root@localhost ~]# reboot 
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.

$ vagrant ssh 
Last login: Tue Aug 29 03:45:57 2017 from 192.168.121.1
Fedora Atomic Host is Awesome! Edited with nano!
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# 
[root@localhost ~]# rpm -q strace docker
strace-4.18-1.fc26.x86_64
docker-1.13.1-21.git27e468e.fc26.x86_64
```

Additionally the `httpd` container is up and running just fine:

```nohighlight
[root@localhost ~]# docker ps
CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS              PORTS                                               NAMES
03fb1de49dd7        a16c8800bb14        "/usr/bin/run-httpd"   14 minutes ago      Up 29 seconds       80/tcp, 443/tcp, 8443/tcp, 0.0.0.0:8000->8080/tcp   httpd
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

# Part 4 Wrap Up

Part 4 of this lab has included package layering, and overriding base
packages by removing them on the system. We also replaced our python 
based web service with a container based service and then tested
override replacing the docker rpm from the base system with a new version.
These features give Atomic Host some of the flexibility it needs when
hacking on these systems every day, but hopefully are not generally
needed for a typical system administrator.

In the [next lab](/2017/09/02/atomic-host-101-lab-part-4-package-layering-experimental-features/)
we'll cover treating Atomic Host as a more generic
platform for applications, not just containerized applications.
