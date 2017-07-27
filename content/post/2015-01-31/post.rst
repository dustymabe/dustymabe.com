---
title: "Crisis Averted.. I'm using Atomic Host"
tags:
date: "2015-01-31"
published: true
---


.. Crisis Averted.. I'm using Atomic Host
.. ======================================

This blog has been running on Docker on Fedora 21 Atomic Host since early January.
Occasionally I log in and run ``rpm-ostree upgrade`` followed by a subsequent 
``reboot`` (usually after I inspect a few things). Today I happened to do just that
and what did I come up with?? A bunch of 404s. Digging through some of the logs for 
the ``systemd`` unit file I use to start my wordpress container I found this::

    systemd[1]: wordpress-server.service: main process exited, code=exited, status=1/FAILURE
    docker[2321]: time="2015-01-31T19:09:24-05:00" level="fatal" msg="Error response from daemon: Cannot start container 51a2b8c45bbee564a61bcbffaee5bc78357de97cdd38918418026c26ae40fb09: write /sys/fs/cgroup/memory/system.slice/docker-51a2b8c45bbee564a61bcbffaee5bc78357de97cdd38918418026c26ae40fb09.scope/memory.memsw.limit_in_bytes: invalid argument"

Hmmm.. So that means I have updated to the latest atomic and ``docker`` doesn't work?? 
What am I to do? 

Well, the nice thing about atomic host is that in moments like these you can easily go 
back to the state you were before you upgraded. A quick ``rpm-ostree rollback`` and 
my blog was back up and running in minutes.

Whew! Crisis averted.. But now what? Well the nice thing about atomic host is that I can
easily go to another (non-production) system and test out exactly the same scenario as the
upgrade that I performed in production. Some quick googling led me to this_ github issue
which looks like it has to do with setting memory limits when you start a container using 
later versions of systemd.

.. _this: https://github.com/docker/docker/issues/10280


Let's test out that theory by recreating this failure.


Recreating the Failure
----------------------

.. _image: http://download.fedoraproject.org/pub/fedora/linux/releases/21/Cloud/Images/x86_64/Fedora-Cloud-Base-20141203-21.x86_64.qcow2

To recreate I decided to start with the Fedora 21 atomic cloud image_ that was
released in December. Here is what I have:: 

    -bash-4.3# ostree admin status
    * fedora-atomic ba7ee9475c462c9265517ab1e5fb548524c01a71709539bbe744e5fdccf6288b.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3#
    -bash-4.3# rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME            REFSPEC
    * 2014-12-03 01:30:09     ba7ee9475c     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3#
    -bash-4.3# rpm -q docker-io systemd
    docker-io-1.3.2-2.fc21.x86_64
    systemd-216-12.fc21.x86_64
    -bash-4.3#
    -bash-4.3# docker run --rm --memory 500M busybox echo "I'm Alive"
    Unable to find image 'busybox' locally
    Pulling repository busybox
    4986bf8c1536: Download complete 
    511136ea3c5a: Download complete 
    df7546f9f060: Download complete 
    ea13149945cb: Download complete 
    Status: Downloaded newer image for busybox:latest
    I'm Alive


So the system is up and running and able to run a container with the ``--memory``
option set. Now lets upgrade to the same commit that I did when I saw the failure
earlier and reboot::

    -bash-4.3# ostree pull fedora-atomic 153f577dc4b039e53abebd7c13de6dfafe0fb64b4fdc2f5382bdf59214ba7acb

    778 metadata, 4374 content objects fetched; 174535 KiB transferred in 156 seconds
    -bash-4.3#
    -bash-4.3# echo 153f577dc4b039e53abebd7c13de6dfafe0fb64b4fdc2f5382bdf59214ba7acb > /ostree/repo/refs/remotes/fedora-atomic/fedora-atomic/f21/x86_64/docker-host
    -bash-4.3#
    -bash-4.3# ostree admin deploy fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    Copying /etc changes: 26 modified, 4 removed, 36 added
    Transaction complete; bootconfig swap: yes deployment count change: 1
    -bash-4.3#
    -bash-4.3# ostree admin status
      fedora-atomic 153f577dc4b039e53abebd7c13de6dfafe0fb64b4fdc2f5382bdf59214ba7acb.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    * fedora-atomic ba7ee9475c462c9265517ab1e5fb548524c01a71709539bbe744e5fdccf6288b.0
        origin refspec: fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3# 
    -bash-4.3# rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME            REFSPEC
      2015-01-31 21:08:35     153f577dc4     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    * 2014-12-03 01:30:09     ba7ee9475c     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3# reboot


Note that I had to manually update the ref to point to the commit I downloaded
in order to get this to work. I'm not sure why this is but it wouldn't work otherwise. 

Ok now I had a system using the same tree that I was when I saw the failure. Let's
check to see if it still happens::

    -bash-4.3# rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME            REFSPEC
    * 2015-01-31 21:08:35     153f577dc4     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
      2014-12-03 01:30:09     ba7ee9475c     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3#
    -bash-4.3# rpm -q docker-io systemd
    docker-io-1.4.1-5.fc21.x86_64
    systemd-216-17.fc21.x86_64
    -bash-4.3#
    -bash-4.3# docker run --rm --memory 500M busybox echo "I'm Alive"
    FATA[0003] Error response from daemon: Cannot start container d79629bfddc7833497b612e2b6d4cc2542ce9a8c2253d39ace4434bbd385185b: write /sys/fs/cgroup/memory/system.slice/docker-d79629bfddc7833497b612e2b6d4cc2542ce9a8c2253d39ace4434bbd385185b.scope/memory.memsw.limit_in_bytes: invalid argument


Yep! Looks like it consistently happens. This is good because this is a recreator that 
can now be used by anyone to verify the problem on their own. For completeness I'll go 
ahead and rollback the system to show that the problem goes away when back in the old
state::

    -bash-4.3# rpm-ostree rollback 
    Moving 'ba7ee9475c462c9265517ab1e5fb548524c01a71709539bbe744e5fdccf6288b.0' to be first deployment
    Transaction complete; bootconfig swap: yes deployment count change: 0
    Changed:
      NetworkManager-1:0.9.10.0-13.git20140704.fc21.x86_64
      NetworkManager-glib-1:0.9.10.0-13.git20140704.fc21.x86_64
      ...
      ...
    Removed:
      flannel-0.2.0-1.fc21.x86_64
    Sucessfully reset deployment order; run "systemctl reboot" to start a reboot
    -bash-4.3# reboot


And the final test::

    -bash-4.3# rpm-ostree status
      TIMESTAMP (UTC)         ID             OSNAME            REFSPEC
    * 2014-12-03 01:30:09     ba7ee9475c     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
      2015-01-31 21:08:35     153f577dc4     fedora-atomic     fedora-atomic:fedora-atomic/f21/x86_64/docker-host
    -bash-4.3# docker run --rm --memory 500M busybox echo "I'm Alive"
    I'm Alive


| Bliss! And you can thank Atomic Host for that.
|
| Dusty
