---
title: 'Atomic Host 101 Lab Part 5: Containerized and Non-Containerized Applications'
author: dustymabe
date: 2017-09-03
tags: [ fedora, atomic ]
draft: false
---

# Introduction

In [Part 4](/2017/09/02/atomic-host-101-lab-part-4-package-layering-experimental-features/)
of this series we learned about package layering and experimental
features of atomic host OSTree mutations. This included installing
packages from external repositories as well as removing and replacing
components of the base OSTree that was delivered with Atomic Host. We
also converted our localweb service to be hosted by a local
docker container running the httpd software rather than Python 3.

In this section of the lab we'll talk a litte bit more about
**Containerized and Non-Containerized Applications** and the role
Atomic Host plays.

# Containerized Applications

From the beginning Atomic Host has considered containerized
applications as the primary use case target. This is still true today
and there continues to be features that are added to the Host through
many tools like
[Atomic CLI](https://github.com/projectatomic/atomic),
[Skopeo](https://github.com/projectatomic/skopeo),
[Bubblewrap](https://github.com/projectatomic/bubblewrap), and many more.

For example, another new technology, known as 
[System Containers](https://github.com/projectatomic/atomic-system-containers),
is currently being proofed out and will soon be the default for running
Kubernetes on top of Atomic Host (i.e. Kubernetes will not be
delivered as an RPM inside of Atomic Host, but will run as a System
Container instead). 

While containerized applications are still a main goal of the
community around Atomic Host, there are many more options now
available to us because the underlying technology has improved so
much. 

# Non-Containerized Applications

Now that Atomic Host has features like package layering and some of
the experimental features mentioned in Part 4, we can now host
traditional applications on Atomic Host as well.

For example, the same web service that we now have containerized on
our Atomic Host, we can replace with an `httpd` RPM on
the host if desired. Let's install `httpd` on the system and, just
for fun, let's show off the fact that you can combine rebase/upgrade
operations with package layering operations by rebasing to a Fedora
rawhide OSTree:

```nohighlight
[root@localhost ~]# rpm-ostree rebase local:fedora/rawhide/x86_64/atomic-host --install httpd
2 metadata, 0 content objects fetched; 884 B transferred in 0 seconds
Checking out tree 55a65a6... done
Enabled rpm-md repositories: localyum
rpm-md repo 'localyum' (cached); generated: 2017-08-28 22:07:11

Importing metadata 100%
Resolving dependencies... done
Importing: 100%
Relabeling 2 packages: 100%
Applying 10 overlays... done
Running pre scripts... 1 done
Running post scripts... 6 done
Writing rpmdb... done
Writing OSTree commit... done
Copying /etc changes: 23 modified, 4 removed, 74 added
Transaction complete; bootconfig swap: yes deployment count change: 0
Freed pkgcache branches: 3 size: 77.0 MB
Upgraded:
...
  kernel 4.12.8-300.fc26 -> 4.13.0-0.rc6.git2.1.fc28
...
Added:
  httpd-2.4.27-6.fc27.x86_64
...
Run "systemctl reboot" to start a reboot
[root@localhost ~]#
[root@localhost ~]# 
[root@localhost ~]# reboot 
Connection to 192.168.121.57 closed by remote host.
Connection to 192.168.121.57 closed.
$ vagrant ssh 
Last login: Tue Aug 29 03:52:25 2017 from 192.168.121.1
Fedora Atomic Host is Awesome! Edited with nano!
[vagrant@localhost ~]$ 
[vagrant@localhost ~]$ 
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# 
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● local:fedora/rawhide/x86_64/atomic-host
                   Version: Rawhide.20170824.n.0 (2017-08-24 14:35:23)
                BaseCommit: 55a65a66f736e7637a23ddb9b649546d7b4ea247c35e32f61047dc7882d08a93
           LayeredPackages: htop httpd nano

  local:fedora/26/x86_64/updates/atomic-host
                   Version: 26.115 (2017-08-26 19:46:28)
                BaseCommit: a8db0b7d3f2e54e4092d5ed640087934b8424637cfa1e3ce4bbaf7ccccfd09a5
           LayeredPackages: htop nano
```

After the reboot we are now on Fedora Rawhide, with the `htop`, `nano`, and
`httpd` packages layered. Since we are on Rawhide now, let's add some
new info to our MOTD:

```nohighlight
[root@localhost ~]# nano /etc/motd 
[root@localhost ~]# 
[root@localhost ~]# cat /etc/motd
Fedora Rawhide Atomic Host is Awesome! Edited with nano!
```

We can also do a sanity check to see what version of `docker` we are
on and if the containerized service is still working:

```nohighlight
[root@localhost ~]# rpm -q docker
docker-1.13.1-30.gitb5e3294.fc28.x86_64
[root@localhost ~]# docker ps
CONTAINER ID        IMAGE               COMMAND                CREATED             STATUS              PORTS                                               NAMES
03fb1de49dd7        a16c8800bb14        "/usr/bin/run-httpd"   22 minutes ago      Up 29 seconds       80/tcp, 443/tcp, 8443/tcp, 0.0.0.0:8000->8080/tcp   httpd
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

Now let's kill that container in preparation of replacing it with a
traditional host based httpd process:

```nohighlight
[root@localhost ~]# docker rm -f httpd 
httpd
```

And we can now set up the system for sharing httpd content:

```nohighlight
[root@localhost ~]# chcon -R unconfined_u:object_r:httpd_sys_content_t:s0 /srv/localweb/
[root@localhost ~]# rmdir /var/www/html
[root@localhost ~]# ln -s /srv/localweb/ /var/www/html
[root@localhost ~]# sed -i 's|Listen 80|Listen 8000|' /etc/httpd/conf/httpd.conf
[root@localhost ~]# semanage port -m -t http_port_t -p tcp 8000
```

The commands above fixed up some selinux labels, symlinked `/var/www/html`
to `/srv/localweb`, specified for `httpd` to listen on port 8000 and
also reclaimed port 8000 from whatever `soundd_port_t` is (this is
what the `semanage` command is doing).

Now we can start the web service:

```nohighlight
[root@localhost ~]# systemctl enable --now httpd
Created symlink /etc/systemd/system/multi-user.target.wants/httpd.service → /usr/lib/systemd/system/httpd.service.
[root@localhost ~]# systemctl status httpd -o cat
● httpd.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2017-08-29 04:06:28 UTC; 11s ago
     Docs: man:httpd.service(8)
 Main PID: 1407 (httpd)
   Status: "Total requests: 0; Idle/Busy workers 100/0;Requests/sec: 0; Bytes served/sec:   0 B/sec"
    Tasks: 213 (limit: 4915)
   CGroup: /system.slice/httpd.service
           ├─1407 /usr/sbin/httpd -DFOREGROUND
           ├─1408 /usr/sbin/httpd -DFOREGROUND
           ├─1409 /usr/sbin/httpd -DFOREGROUND
           ├─1410 /usr/sbin/httpd -DFOREGROUND
           └─1412 /usr/sbin/httpd -DFOREGROUND

Starting The Apache HTTP Server...
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using localhost.l
Started The Apache HTTP Server.
```

We can also see that the new service is working:

```nohighlight
[root@localhost ~]# 
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```

# Part 5 Wrap Up

In Part 5 of this lab we have shown that you can use Atomic Host for
either containerized **OR** non-containerized applications. While
containerized applications may be a more preferred method of running the
services on Atomic Host, the user is ultimately the one to decide.
If the user would like to use containers, that's great. If the user
would rather package layer, that works too.
A hybrid approach of running some applications in containers and
layering in some software as RPMs on the host is most likely a happy
medium that most people will end up doing. Being able to do both of
these is really a testament to the strengths of the OSTree and
rpm-ostree technologies.

# Thanks

Thanks for sticking with the lab and making it to the end.
Ultimately the [Atomic Host Working Group](https://fedoraproject.org/wiki/Atomic_WG) 
would like for people to use
Atomic Host in whatever way works for them and to be a part of the
community that helps shape the future of this project.

If you are interested, please join us in the community in #atomic on
Freenode or on the atomic-devel@projectatomic.io mailing.
