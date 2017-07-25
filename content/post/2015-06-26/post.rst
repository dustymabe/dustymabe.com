---
title: "None"
tags: [ "1", "2" ]
date: "2012-02-09"
published: false
---
.. Atomic Host Red Hat Summit Lab
.. ==============================

Red Hat Summit was a blast this year. I participated in several Hands On
Labs to help the community learn about the new tools that are
available in the ecosystem. For one of the labs I wrote up a section
on Atomic Host, but more specifically on ``rpm-ostree``. I have copied
a portion of the lab here as well as added example text to the code blocks.

Lab Intro
---------

Atomic Host is a minimalistic operating system that is designed
to contain a very small subset of tools that are needed for running
container based applications. A few of it's features are shown below:

- It is Lightweight
  * a small base means less potential issues.

- Provides Atomic Upgrades and Rollbacks
  * upgrades/rollbacks are staged and take effect on reboot

- Static and Dynamic
  * software/binaries in /usr and other similar directories are read-only
    + this guarantees no changes have been made to the software

  * configuration and temporary directories are read/write
    + you can still make important configuration changes and have them propagate forward


We will explore some of these features as we illustrate a bit of the
lifecycle of managing a RHEL Atomic Host. 

Hello rpm-ostree World
----------------------

In an ``rpm-ostree`` world you can't install new software on the system
or even touch most of the software that exists. Go ahead and try::

    -bash-4.2# echo 'Crazy Talk' > /usr/bin/docker
    -bash: /usr/bin/docker: Read-only file system

What we can do is configure the existing software on the system using the
provided mechanisms for configuration. We can illustrate this by writing 
to ``motd`` and then logging in to see the message::

    -bash-4.2# echo 'Lab 1 is fun' > /etc/motd
    -bash-4.2# ssh root@localhost
    Last login: Fri Jun  5 02:26:59 2015 from localhost
    Lab 1 is fun
    -bash-4.2# exit
    logout
    Connection to localhost closed.

Even though we can't install new software, your Atomic Host operating
system isn't just a black box. The ``rpm`` command is there and we can
run queries just the same as if we were on a traditional system. This
is quite useful because we can use the tools we are familiar with to
investigate the system. Try out a few rpm queries on the Atomic Host::

    -bash-4.2# rpm -q kernel
    kernel-3.10.0-229.4.2.el7.x86_64
    -bash-4.2# rpm -qf /usr/bin/vi
    vim-minimal-7.4.160-1.el7.x86_64
    -bash-4.2# rpm -q --changelog util-linux | wc -l
    1832

Another nice thing about ``atomic``, or rather the underlying ``ostree``
software is that it is like ``git`` for your OS. At any point in time
you can see what has changed between what was delivered in the tree 
vs. what is on the system. That means for those few directories that
are read/write, you can easily view what changes have been made to
them.

Let's take a look at the existing differences between what we have and 
what was delivered in the tree::

    -bash-4.2# ostree admin config-diff | head -n 5
    M    adjtime
    M    motd
    M    group
    M    hosts
    M    gshadow

You can see right in the middle the the ``motd`` file we just modified.

As a final step before we do an upgrade let's run a container and
verify all is working::


    -bash-4.2# docker run -d -p 80:80 --name=test
    repo.atomic.lab:5000/apache
    e18a5f7d54c8dbe0d352e2c2854af16d27f166d11b95bc37a3b4267cfcd39cd6
    -bash-4.2# curl http://localhost
    Apache
    -bash-4.2# docker rm -f test
    test


Performing an Upgrade
---------------------

Ok, now that we have took a little tour, let's actually perform an
upgrade in which we move from one version of the tree to a newer
version. First, let's check the current status of the system::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         VERSION   ID             OSNAME               REFSPEC
    * 2015-05-30 04:10:40               d306dcf255     rhel-atomic-host     lab:labtree
      2015-05-07 19:00:48     7.1.2     203dd666d3     rhel-atomic-host     rhel-atomic-host-ostree:rhel-...


Note that the ``*`` indicates which tree is currently
booted. The ID is a short commit ID for that commit in the tree. The REFSPEC
for the latest tree specifies the remote we are using (``lab``) and the ref
that we are tracking (``labtree``). Quite a lot of information!

A fun fact is that the ``atomic host`` command is just a frontend for the 
``rpm-ostree`` utility. It has some of the functionality of the ``rpm-ostree``
utility that is suitable for most daily use. Let's use ``rpm-ostree`` now to check 
the status::

    -bash-4.2# rpm-ostree status
      TIMESTAMP (UTC)         VERSION   ID             OSNAME               REFSPEC
    * 2015-05-30 04:10:40               d306dcf255     rhel-atomic-host     lab:labtree
      2015-05-07 19:00:48     7.1.2     203dd666d3     rhel-atomic-host     rhel-atomic-host-ostree:rhel-...

The next step is to actually move to a new tree. For the purposes of
this lab, and to illustrate Atomic's usefulness, we are actually going
to upgrade to a tree that has some bad software in it. If we were to
run an ``atomic host upgrade`` command then it would actually take us to
the newest commit in the repo. In this case we want to go to an
intermediate commit (a bad one) so we are going to run a special
command to get us there::

    -bash-4.2# rpm-ostree rebase lab:badtree

    26 metadata, 37 content objects fetched; 101802 KiB transferred in 7 seconds
    Copying /etc changes: 26 modified, 8 removed, 70 added
    Transaction complete; bootconfig swap: yes deployment count change: 0
    Freed objects: 180.1 MB
    Deleting ref 'lab:labtree'
    Changed:
      etcd-2.0.11-2.el7.x86_64
      kubernetes-0.17.1-1.el7.x86_64
    Removed:
      setools-console-3.3.7-46.el7.x86_64

What we did there was rebase to another ref (``badtree``), but we kept with the 
same remote (``lab``).

So we have rebased to a new tree but we aren't yet using that tree. 
During upgrade the new environment is staged for the next boot, but 
not yet being used. This allows the upgrade to be **atomic**. Before 
we reboot we can check the status. You will see the new tree as well 
as the old tree listed. The ``*`` still should be next to the old tree
since that is the tree that is currently booted and running::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         ID             OSNAME               REFSPEC
      2015-05-30 04:39:22     146b72d9d7     rhel-atomic-host     lab:badtree
    * 2015-05-30 04:10:40     d306dcf255     rhel-atomic-host     lab:labtree

After checking the status reboot the machine in order to boot into the
new tree.


Rolling Back
------------

So why would you ever need to roll back? It's a perfect world and
nothing ever breaks right? No! Sometimes problems arise and it is
always nice to have an *undo* button to fix it. In the case of Atomic,
there is ``atomic host rollback``. Do we need to use it now? Let's
see if everything is OK on the system::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         ID             OSNAME               REFSPEC
    * 2015-05-30 04:39:22     146b72d9d7     rhel-atomic-host     lab:badtree
      2015-05-30 04:10:40     d306dcf255     rhel-atomic-host     lab:labtree
    -bash-4.2# 
    -bash-4.2# docker run -d -p 80:80 --name=test repo.atomic.lab:5000/apache
    ERROR
    -bash-4.2# curl http://localhost
    curl: (7) Failed connect to localhost:80; Connection refused
    -bash-4.2# systemctl --failed | head -n 3
    UNIT           LOAD   ACTIVE SUB    DESCRIPTION
    docker.service loaded failed failed Docker Application Container Engine

Did anything fail? Of course it did. So let's press the eject button
and get ourselves back to safety::

    -bash-4.2# atomic host rollback
    Moving 'd306dcf255b370e5702206d064f2ca2e24d1ebf648924d52a2e00229d5b08365.0' to be first deployment
    Transaction complete; bootconfig swap: yes deployment count change: 0
    Changed:
      etcd-2.0.9-2.el7.x86_64
      kubernetes-0.15.0-0.4.git0ea87e4.el7.x86_64
    Added:
      setools-console-3.3.7-46.el7.x86_64
    Sucessfully reset deployment order; run "systemctl reboot" to start a reboot
    -bash-4.2# reboot

Now, let's check to see if we are back to a good state::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         ID             OSNAME               REFSPEC
    * 2015-05-30 04:10:40     d306dcf255     rhel-atomic-host     lab:labtree
      2015-05-30 04:39:22     146b72d9d7     rhel-atomic-host     lab:badtree
    -bash-4.2# docker run -d -p 80:80 --name=test repo.atomic.lab:5000/apache
    a28a5f80bc2d1da9d405199f88951a62a7c4c125484d30fbb6eb2c4c032ef7f3
    -bash-4.2# curl http://localhost
    Apache
    -bash-4.2# docker rm -f test
    test

All dandy! 


Final Upgrade
-------------

So since the badtree has been released the developers fixed the bug
and have put out a new tree that is fixed. Now we can upgrade to the
newest tree. As part of this upgrade let's explore some of the
``rpm-ostree`` features. 

First, create a file in ``/etc/`` and show that ostree knows that it has
been created and differs from the tree that was delivered::

    -bash-4.2# echo "Before Upgrade d306dcf255" > /etc/before-upgrade.txt
    -bash-4.2# ostree admin config-diff | grep before-upgrade
    A    before-upgrade.txt

Now we can do the upgrade::

    -bash-4.2# atomic host upgrade --reboot
    Updating from: lab:labtree

    48 metadata, 54 content objects fetched; 109056 KiB transferred in 9 seconds
    Copying /etc changes: 26 modified, 8 removed, 74 added
    Transaction complete; bootconfig swap: yes deployment count change: 0

After the upgrade let's actually run a few commands to see the actual 
difference is (in terms of rpms) between the two trees::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         ID             OSNAME               REFSPEC
    * 2015-05-30 05:12:55     ec89f90273     rhel-atomic-host     lab:labtree
      2015-05-30 04:10:40     d306dcf255     rhel-atomic-host     lab:labtree
    -bash-4.2# rpm-ostree db diff -F diff d306dcf255 ec89f90273
    ostree diff commit old: d306dcf255 (d306dcf255b370e5702206d064f2ca2e24d1ebf648924d52a2e00229d5b08365)
    ostree diff commit new: ec89f90273 (ec89f902734e70b4e8fbe5000e87dd944a3c95ffdb04ef92f364e5aaab049813)
    !atomic-0-0.22.git5b2fa8d.el7.x86_64
    =atomic-0-0.26.gitcc9aed4.el7.x86_64
    !docker-1.6.0-11.el7.x86_64
    =docker-1.6.0-15.el7.x86_64
    !docker-python-1.0.0-35.el7.x86_64
    =docker-python-1.0.0-39.el7.x86_64
    !docker-selinux-1.6.0-11.el7.x86_64
    =docker-selinux-1.6.0-15.el7.x86_64
    !docker-storage-setup-0.0.4-2.el7.noarch
    =docker-storage-setup-0.5-2.el7.x86_64
    !etcd-2.0.9-2.el7.x86_64
    =etcd-2.0.11-2.el7.x86_64
    !kubernetes-0.15.0-0.4.git0ea87e4.el7.x86_64
    =kubernetes-0.17.1-4.el7.x86_64
    +kubernetes-master-0.17.1-4.el7.x86_64
    +kubernetes-node-0.17.1-4.el7.x86_64
    !python-websocket-client-0.14.1-78.el7.noarch
    =python-websocket-client-0.14.1-82.el7.noarch
    -setools-console-3.3.7-46.el7.x86_64

This shows added, removed, changed rpms between the two trees.

Now remember that file we created before the upgrade? Is it still
there? Let's check and also create a new file that represents the 
*after upgrade* state::

    -bash-4.2# cat /etc/before-upgrade.txt
    Before Upgrade d306dcf255
    -bash-4.2# echo "After Upgrade ec89f90273" > /etc/after-upgrade.txt
    -bash-4.2# cat /etc/after-upgrade.txt
    After Upgrade ec89f90273


Now which of the files do you think will exist after a rollback? Only
you can find out!:: 

    -bash-4.2# rpm-ostree rollback --reboot 
    Moving 'd306dcf255b370e5702206d064f2ca2e24d1ebf648924d52a2e00229d5b08365.0' to be first deployment
    Transaction complete; bootconfig swap: yes deployment count change: 0

After rollback::

    -bash-4.2# atomic host status
      TIMESTAMP (UTC)         ID             OSNAME               REFSPEC         
    * 2015-05-30 04:10:40     d306dcf255     rhel-atomic-host     lab:labtree     
      2015-05-30 05:12:55     ec89f90273     rhel-atomic-host     lab:labtree     
    -bash-4.2# ls -l /etc/*.txt
    -rw-r--r--. 1 root root 26 Jun  5 03:35 /etc/before-upgrade.txt

Fin!
----

Now you know quite a bit about upgrading, rolling back, and querying
information from your Atomic Host. Have fun exploring!

| Dusty
