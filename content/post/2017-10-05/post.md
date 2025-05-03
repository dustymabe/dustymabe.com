---
title: 'Setting up an Atomic Host Build Server'
author: dustymabe
date: 2017-10-05
tags: [ fedora, atomic ]
draft: false
---

# Introduction

Hosting your own Atomic Host OSTree can be useful from time to time.
Maybe you want to try out something new or maybe you want to permanently
build your own custom tree and use it forever. It can be quite easy to set
up a build server and host the contents, especially for personal use.

This post will walk through setting up a server to do builds and also
hosting the content over http.

# Choosing A Host

For this example we are going to use a Fedora 26 Atomic Host as the
server to build the tree and host the content.

```nohighlight
[root@compose-server ~]# rpm-ostree status
State: idle
Deployments:
● fedora-atomic:fedora/26/x86_64/atomic-host
                   Version: 26.131 (2017-09-19 22:29:04)
                    Commit: 98088cb6ed2a4b3f7e4e7bf6d34f9e137c296bc43640b4c1967631f22fe1802f
              GPGSignature: Valid signature by E641850B77DF435378D1D7E2812A6B4B64DAB85D
```

Atomic Host already has the `ostree` and `rpm-ostree` software on the
system. If you want to run this on plain Fedora you will need to
`dnf install rpm-ostree ostree`. 

One thing to do before moving forward is to choose where we will store
the OSTree contents. For this post we'll put the files under `/srv/`
and we'll just extend the root filesystem to accommodate. Let's go
ahead and extend the root filesystem now:

```nohighlight
[root@compose-server ~]# lvresize --size=+20g --resizefs atomicos/root
  Size of logical volume atomicos/root changed from 2.93 GiB (750 extents) to 22.93 GiB (5870 extents).
  Logical volume atomicos/root successfully resized.
meta-data=/dev/mapper/atomicos-root isize=512    agcount=4, agsize=192000 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1 spinodes=0 rmapbt=0
         =                       reflink=0
data     =                       bsize=4096   blocks=768000, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal               bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 768000 to 6010880
```


# Getting/Changing An Existing treecompose Manifest Defintion

What we want to do is run a compose via a command like 
`rpm-ostree compose tree tree-definition.json`. What tree
definition should we use? You can come up with your own tree
definition, but for this case I'll re-use the one that is used
for Fedora 27 Atomic Host: 
[fedora-atomic-host.json](https://pagure.io/fedora-atomic/blob/f27/f/fedora-atomic-host.json).

Some other files in [that repo](https://pagure.io/fedora-atomic/tree/f27) matter as well, (`fedora-27.repo`,
`treecompose-post.sh`, etc..) so it's probably best just to
`git clone`:

**NOTE**: A more comprehensive overview of the manifest file and
          setting up your own server can be found 
          [in the documentation.](https://rpm-ostree.readthedocs.io/en/latest/manual/compose-server/)

```nohighlight
[root@compose-server ~]# cd /srv/
[root@compose-server srv]# atomic run registry.fedoraproject.org/f26/tools
docker run -it --name tools --privileged --ipc=host --net=host --pid=host -e HOST=/host -e NAME=tools -e IMAGE=registry.fedoraproject.org/f26/tools -v /run:/run -v /var/log:/var/log -v /etc/machine-id:/etc/machine-id -v /etc/localtime:/etc/localtime -v /:/host registry.fedoraproject.org/f26/tools

This container uses privileged security switches:

INFO: --privileged
      This container runs without separation and should be considered the same as root on your system.

INFO: --net=host
      Processes in this container can listen to ports (and possibly rawip traffic) on the host's network.

INFO: --pid=host
      Processes in this container can see and interact with all processes on the host and disables SELinux within the container.

INFO: --ipc=host
      Processes in this container can see and possibly interact with all semaphores and shared memory segments on the host as well as disables SELinux within the container.

For more information on these switches and their security implications, consult the manpage for 'docker run'.

[root@compose-server /]# cd /host/srv/
[root@compose-server srv]# git clone -b f27 https://pagure.io/fedora-atomic.git
Cloning into 'fedora-atomic'...
remote: Counting objects: 1275, done.
remote: Compressing objects: 100% (748/748), done.
remote: Total 1275 (delta 805), reused 930 (delta 523)
Receiving objects: 100% (1275/1275), 1.08 MiB | 3.19 MiB/s, done.
Resolving deltas: 100% (805/805), done.
[root@compose-server srv]# ls fedora-atomic/
config.ini      fedora-atomic-host.json    group   README-content  TODO.md              web
fedora-27.repo  fedora-atomic-rawhide.tdl  passwd  README.md       treecompose-post.sh
```

Since git isn't installed on atomic host I used the
[tools container](https://src.fedoraproject.org/container/tools)
, which has `git` installed. Ideally I would have also just downloaded
the tarball/archive of the repo, but [pagure](https://pagure.io/pagure)
doesn't yet support doing that.

Now that we have the treecompose manifest definition, let's tweak it a bit. In
this case I'd like to make an OSTree that includes content from the
Fedora 27 Updates Testing repository. This repository happens to
already be defined in the `fedora-27.repo` file, we just need to add
it into the list of repos already in the `fedora-atomic-host.json`
file. We'll update the `"repos":` list to be:

```nohighlight
"repos": ["fedora-27", "fedora-27-updates", "fedora-27-updates-testing"],
```

# Composing A Tree For The First Time

First things first, we need to initialize a repo before we
can compose a tree. We'll make one under `/srv/repo`:

```nohighlight
[root@compose-server ~]# mkdir /srv/repo
[root@compose-server ~]# ostree init --repo=/srv/repo/ --mode=archive
[root@compose-server ~]# ls /srv/repo/
config  extensions  objects  refs  state  tmp  uncompressed-objects-cache
```

Now we can do our first treecompose:

```nohighlight
[root@compose-server ~]# rpm-ostree compose tree --repo=/srv/repo /srv/fedora-atomic/fedora-atomic-host.json
No previous commit for fedora/27/x86_64/atomic-host
Enabled rpm-md repositories: fedora-27 fedora-27-updates fedora-27-updates-testing
Updating metadata for 'fedora-27': 100%
rpm-md repo 'fedora-27'; generated: 2017-10-04 11:26:24

Updating metadata for 'fedora-27-updates': 100%
rpm-md repo 'fedora-27-updates'; generated: 2017-08-18 21:55:15

Updating metadata for 'fedora-27-updates-testing': 100%
rpm-md repo 'fedora-27-updates-testing'; generated: 2017-10-02 21:18:23

Importing metadata 100%
Resolving dependencies... done
Installing 458 packages:
  GeoIP-1.6.11-3.fc27.x86_64 (fedora-27)
  GeoIP-GeoLite-data-2017.09-1.fc27.noarch (fedora-27)
...
Will download: 458 packages (322.5 MB)
  Downloading from fedora-27: 100%
  Downloading from fedora-27-updates-testing: 100%
Installing packages: 100%
Executing postprocessing script 'treecompose-post.sh'
Committing: 100%
Metadata Total: 7909
Metadata Written: 3579
Content Total: 32544
Content Written: 25515
Content Bytes Written: 1014385703
fedora/27/x86_64/atomic-host => 1234f194dc43f9394160306a6512f7c024905013b3faefb41356bf7563ec38ce
```

**NOTE**: The output of the compose was truncated in various places
          for brevity.


# Automating The Compose Of A Tree Over Time

It's great that we just did our first tree compose. What about the
future? We don't want to push a button every time. We can use a
simple systemd timer to keep our tree updated when new packages come
available in the repos.

We'll first create a systemd unit for a service that runs the compose.
This service will be known as `f27-updates-testing-rpm-ostree-compose.service`:

```nohighlight
cat <<EOF > /etc/systemd/system/f27-updates-testing-rpm-ostree-compose.service
[Unit]
Description=run rpm-ostree compose for f27 updates-testing

[Service]
Type=oneshot
ExecStart=/usr/bin/rpm-ostree compose tree --repo=/srv/repo /srv/fedora-atomic/fedora-atomic-host.json
User=root
EOF
```

Then we'll create a systemd timer that calls the service every day
at `16:00`:

```nohighlight
cat <<EOF > /etc/systemd/system/f27-updates-testing-rpm-ostree-compose.timer
[Unit]
Description=run rpm-ostree f27 updates-testing compose daily

[Timer]
OnCalendar=16:00
Persistent=true
Unit=f27-updates-testing-rpm-ostree-compose.service

[Install]
WantedBy=timers.target
EOF
```

Finally reload systemd to pick up the changes and enable the timer:

```nohighlight
[root@compose-server ~]# systemctl daemon-reload
[root@compose-server ~]# systemctl enable f27-updates-testing-rpm-ostree-compose.timer --now
Created symlink /etc/systemd/system/timers.target.wants/f27-updates-testing-rpm-ostree-compose.timer → /etc/systemd/system/f27-updates-testing-rpm-ostree-compose.timer.
```

After a day you can see the logs by inspecting the
journal for `f27-updates-testing-rpm-ostree-compose.service`
with a command like: `journalctl -u f27-updates-testing-rpm-ostree-compose.service`.


# Hosting The OSTree Repository Over HTTP

There are a million different ways to host the content. Since we're on
Atomic Host, I'll use a container:

```nohighlight
[root@compose-server ~]# docker run -d -p 80:8080 -v /srv/repo/:/var/www/html/:Z --restart=always --name webserver registry.fedoraproject.org/f26/httpd
dbd23eb9e145f11a8ed096ec61b99c7b3c6e46f0c7e5ac224b62faced6f24b77
[root@compose-server ~]#
[root@compose-server ~]# curl localhost/refs/heads/fedora/27/x86_64/atomic-host
1234f194dc43f9394160306a6512f7c024905013b3faefb41356bf7563ec38ce
```

The webserver is up and running and we were able to `curl` to see that
the latest commit in the `fedora/27/x86_64/atomic-host` ref is the one
that we just built above: `1234f194dc43f9394160306a6512f7c024905013b3faefb41356bf7563ec38ce`.

**NOTE**: Firewall rules may need to be added to allow for the content
          to be hosted publicly.


# Rebasing Clients To The New OSTree

Now that we are serving the OSTree over http, we can rebase an
existing host to that tree. In my case I'll rebase an already
existing Fedora 27 host to the updates testing tree we just created:

```nohighlight
[vagrant@vanilla-f27atomic ~]$ sudo ostree remote add myremote http://10.10.10.100/ --no-gpg-verify
[vagrant@vanilla-f27atomic ~]$ sudo rpm-ostree rebase myremote:fedora/27/x86_64/atomic-host
Rebasing to myremote:fedora/27/x86_64/atomic-host
error: Can't pull from archives with mode "bare"
[vagrant@vanilla-f27atomic ~]$
[vagrant@vanilla-f27atomic ~]$ sudo rpm-ostree rebase myremote:fedora/27/x86_64/atomic-host
Rebasing to myremote:fedora/27/x86_64/atomic-host
...
Run "systemctl reboot" to start a reboot
[vagrant@vanilla-f27atomic ~]$ rpm-ostree status
State: idle
Deployments:
  myremote:fedora/27/x86_64/atomic-host
                   Version: 27 (2017-10-05 04:20:27)
                    Commit: 1234f194dc43f9394160306a6512f7c024905013b3faefb41356bf7563ec38ce

● fedora-atomic:fedora/27/x86_64/atomic-host
                   Version: 27.20170929.n.0 (2017-09-29 13:08:11)
                    Commit: fd0817691e3259b6d3d0dc9a628282695bdb5000629a8508416dea4374875da5
              GPGSignature: Valid signature by 860E19B0AFA800A1751881A6F55E7430F5282EE4

```

# Conclusion

Now we have an OSTree compose server that will update the tree daily
and serve the content to users. This is pretty simple to set up for
demo/proof of concept purposes and could be easily extended to more
production-like scenarios (i.e. by adding encyrption via HTTPS, and
signing OSTree commits).

Cheers!
