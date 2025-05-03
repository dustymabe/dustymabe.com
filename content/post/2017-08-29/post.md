---
title: 'Atomic Host 101 Lab Part 0: Preparation'
author: dustymabe
date: 2017-08-29
tags: [ fedora, atomic ]
draft: false
---

# Introduction

While Atomic Host has been around since 2014 there are still a lot of
people that aren't as familiar with the technology. The Atomic team
within Red Hat, along with numerous other upstream contributors, have
brought the [OSTree](https://ostree.readthedocs.io/en/latest/manual/introduction/)
and [RPM-OSTree](https://rpm-ostree.readthedocs.io/en/latest/)
technology a long way. At the Fedora user and contributor conference (known as 
[Flock](https://flocktofedora.org/)) this week we will be
giving a [lab on Atomic Host](https://flock2017.sched.com/event/Bm97/atomic-host-101)
designed to let new users learn about
Atomic Host. The audience for this lab is anyone familiar with Linux
and interested in learning a new technology.

The entire lab will cover quite a few features of Atomic Host
including:

- Getting Familiar With Atomic Host
- Viewing Changes To A Deployed System
- Configuring Storage for Containers
- Atomic Host Rebasing 
- Atomic Host Upgrades and Rollbacks
- Browsing OS History
- Package Layering
- Experimental Features (livefs, remove, replace)
- Containerized and Non-Containerized Applications

In *Part 0: Preparation* we are going to set up an existing Fedora 26
Atomic Host for the rest of the lab sections.


# Getting A Fedora 26 Atomic Host

In this lab you'll need to start with a Fedora 26 Atomic Host. It is
recommended you start from the `26.110` (`13ed0f2`) release. The
corresponding media that was built from that release was part of
the `26-20170821.0` compose. You can spin up this release by booting 
in AWS or by spinning up a vagrant box or cloud image. Information on
AMIs or links to downloads can be found [here](/2017-08-29/imageinfo.txt).

For demonstration purposes I'll be using the libvirt vagrant box. If
you are on Fedora please see the [Fedora Developer Portal](https://developer.fedoraproject.org/tools/vagrant/about.html)
for instructions on how to get started with Vagrant.

After downloading the libvirt vagrant box
(`Fedora-Atomic-Vagrant-26-20170821.0.x86_64.vagrant-libvirt.box`)
we can now add the box to Vagrant: 

```nohighlight
$ vagrant box add --name F26AHLab ./Fedora-Atomic-Vagrant-26-20170821.0.x86_64.vagrant-libvirt.box
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'F26AHLab' (v0) for provider:
    box: Unpacking necessary files from: file:///path/Fedora-Atomic-Vagrant-26-20170821.0.x86_64.vagrant-libvirt.box
==> box: Successfully added box 'F26AHLab' (v0) for 'libvirt'!
```

I can now bring up and ssh into the Atomic Host:

```nohighlight
$ mkdir atomic && cd atomic && vagrant init F26AHLab && vagrant up
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
Bringing machine 'default' up with 'libvirt' provider...
==> default: Creating image (snapshot of base box volume).
...
$ vagrant ssh
[vagrant@localhost ~]$
[vagrant@localhost ~]$ sudo su -
[root@localhost ~]# grep PRETTY_NAME /etc/os-release
PRETTY_NAME="Fedora 26 (Atomic Host)"
[root@localhost ~]#
[root@localhost ~]# rpm-ostree status
State: idle
Deployments:
● fedora-atomic:fedora/26/x86_64/atomic-host
                   Version: 26.110 (2017-08-20 18:10:09)
                    Commit: 13ed0f241c9945fd5253689ccd081b5478e5841a71909020e719437bbeb74424
```


# Extend Root Filesystem

For this lab we are going to be adding some files to the root
filesystem and also rebasing to other OSTrees. Let's add a significant
amount of space to the root filesystem to accommodate this:

```nohighlight
[root@localhost ~]# lvresize --resizefs --size=+10G /dev/atomicos/root
  Size of logical volume atomicos/root changed from 2.93 GiB (750 extents) to 12.93 GiB (3310 extents).
  Logical volume atomicos/root successfully resized.
...
``` 

# Download Lab Files Archive

A goal of this lab is to be able to be executed in an offline
scenario. This means we have archived a bunch of files of the lab
and stored them in a tar.gz for consumption. It also means that a
user should be able to execute this lab any time in the future without
worrying about missing necessary files that are no longer on the web.

Please download the [atomic-host-lab.tar.gz](https://201708-atomic-host-lab.nyc3.digitaloceanspaces.com/atomic-host-lab.tar.gz)
file into the `/srv/localweb` directory on the running atomic host:

**NOTE:** If you downloaded the `atomic-host-lab.tar.gz` file before
          you started the Atomic Host then you can use `scp` to copy
          the file in.

```nohighlight
[root@localhost ~]# mkdir /srv/localweb && chmod 777 /srv/localweb
[root@localhost ~]# cd /srv/localweb
[root@localhost localweb]# curl -O https://201708-atomic-host-lab.nyc3.digitaloceanspaces.com/atomic-host-lab.tar.gz
...
[root@localhost localweb]# tar -xf atomic-host-lab.tar.gz
[root@localhost localweb]# rm atomic-host-lab.tar.gz
[root@localhost localweb]# cd
[root@localhost ~]#
```

# Set Up Local Webserver For Archive Files

Throughout this entire lab we'll use a local webserver to host
the files from the archive. Initially this service will use builtin
http server modules within Python. Let's create and start that
service now:


```nohighlight
[root@localhost ~]# cat <<'EOF' > /etc/systemd/system/localweb.service
[Unit]

[Service]
WorkingDirectory=/srv/localweb
ExecStart=/usr/bin/python3 -m http.server

[Install]
WantedBy=multi-user.target
EOF
[root@localhost ~]#
[root@localhost ~]# systemctl daemon-reload
[root@localhost ~]# systemctl enable --now localweb.service
Created symlink /etc/systemd/system/multi-user.target.wants/localweb.service → /etc/systemd/system/localweb.service.
[root@localhost ~]# systemctl status localweb.service
● localweb.service
   Loaded: loaded (/etc/systemd/system/localweb.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2017-08-29 16:36:45 UTC; 5s ago
 Main PID: 2974 (python3)
    Tasks: 1 (limit: 4915)
   Memory: 19.6M
      CPU: 342ms
   CGroup: /system.slice/localweb.service
           └─2974 /usr/bin/python3 -m http.server

Aug 29 16:36:45 localhost.localdomain systemd[1]: Started localweb.service.
[root@localhost ~]#
[root@localhost ~]# curl http://localhost:8000/hello.txt
hello world
```


# Configure OSTree/YUM Repositories

Our local webservice is now running and hosting files that
are a front for an OSTree repository as well as a YUM repository.
Let's remove the old remote from the system and configure it so
that `ostree` pulls from that local server:


```nohighlight
[root@localhost ~]# ostree remote delete fedora-atomic
[root@localhost ~]# ostree remote add --no-gpg-verify local http://localhost:8000/ostreerepo/
```

Let's take it one step farther and tell the current deployment
on the system to track the `fedora/26/x86_64/updates/atomic-host` 
ref from the `local` remote. We'll then restart `rpm-ostreed` to
make the system pick up the changes.

```nohighlight
[root@localhost ~]# ostree admin set-origin --index 0 local http://localhost:8000/ostreerepo/ fedora/26/x86_64/updates/atomic-host
[root@localhost ~]# systemctl restart rpm-ostreed.service
```

Finally, we'll delete all existing YUM repositories and add our
`localyum` repository to the system.

```nohighlight
[root@localhost ~]# rm /etc/yum.repos.d/*.repo
[root@localhost ~]# cat <<'EOF' > /etc/yum.repos.d/localyum.repo
[localyum]
baseurl=http://localhost:8000/yumrepo/
enabled=1
gpgcheck=0
EOF
```

# Part 0 Wrap Up

Part 0 of this lab has been specifically to get the system prepared
for later sections of the lab. You may have some questions. That's OK.
Hopefully we'll answer them in the later sections of this lab. In the
[next post](/2017/08/30/atomic-host-101-lab-part-1-getting-familiar/)
we'll get more familiar with Atomic Host.
