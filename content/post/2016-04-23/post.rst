---
title: "Fedora BTRFS+Snapper - The Fedora 24 Edition"
tags:
date: "2016-04-23"
published: true
---

.. Fedora BTRFS+Snapper - The Fedora 24 Edition
.. ============================================

History
-------

In the past I have configured my personal computers to be able to snapshot and
rollback the entire system. To do this I am leveraging the ``BTRFS`` filesystem, a tool
called ``snapper``, and a patched version of Fedora's ``grub2`` package.
The patches needed from grub2 come from the SUSE guys and are documented well in
this `git repo`_.  

.. _git repo: https://github.com/dustymabe/fedora-grub-boot-btrfs-default-subvolume/tree/master/fedora24

This setup is not new. I have fully documented the steps I took in the past for my Fedora 22
systems in two blog posts: part1_ and part2_. This is a condensed continuation of
those posts for Fedora 24.

.. _part1: http://dustymabe.com/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/
.. _part2: http://dustymabe.com/2015/07/19/fedora-btrfssnapper-part-2-full-system-snapshotrollback/

**NOTE:** I'm using Fedora 24 alpha, but everything should be the same for
the released version of Fedora 24.

Setting up System with LUKS + LVM + BTRFS
-----------------------------------------

The manual steps for setting up the system are detailed in the part1_
blog post from Fedora 22. This time around I have created a script_ 
that will quickly
configure the system with ``LUKS`` + ``LVM`` + ``BTRFS``. The script
will need to be run in an Anaconda environment just like the manual
steps were done in part1_ last time. 

.. _script: http://dustymabe.com/content/2016-04-23/script.sh

You can easily enable ``ssh`` access to your Anaconda booted machine by
adding ``inst.sshd`` to the kernel command line arguments. After 
booting up you can ``scp`` the script over and then execute it to
build the system. Please read over the script and modify it to your
liking.

Alternatively, for an automated install I have embedded that same
script into a `kickstart file`_ that you can use. The kickstart file 
doesn't really leverage Anaconda at all because it simply runs a 
``%pre`` script and then reboots the box. It's basically like just telling
Anaconda to run a bash script, but allows you to do it in an automated way.
None of the kickstart directives at the top of the kickstart file actually get used. 

.. _kickstart file: http://dustymabe.com/content/2016-04-23/ks.cfg

Installing and Configuring Snapper
----------------------------------

After the system has booted for the first time, let's configure the
system for doing snapshots. I still want to be able to track how much
size each snapshot has taken so I'll go ahead and enable ``quota``
support on ``BTRFS``. I covered how to do this in a `previous post`_::

    [root@localhost ~]# btrfs quota enable /
    [root@localhost ~]# btrfs qgroup show /
    qgroupid         rfer         excl 
    --------         ----         ---- 
    0/5           1.08GiB      1.08GiB

.. _previous post: http://dustymabe.com/2013/09/22/btrfs-how-big-are-my-snapshots/

Next up is installing/configuring ``snapper``. I am also going to
install the ``dnf`` plugin for snapper so that rpm transactions will
automatically get snapshotted::

    [root@localhost ~]# dnf install -y snapper python3-dnf-plugins-extras-snapper
    ...
    Complete!
    [root@localhost ~]# snapper --config=root create-config /
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date | User | Cleanup | Description | Userdata
    -------+---+-------+------+------+---------+-------------+---------
    single | 0 |       |      | root |         | current     |         
    [root@localhost ~]# snapper list-configs
    Config | Subvolume
    -------+----------
    root   | /        
    [root@localhost ~]# btrfs subvolume list /
    ID 259 gen 57 top level 5 path .snapshots

So we used the ``snapper`` command to create a configuration for
``BTRFS`` filesystem mounted at ``/``. As part of this process we can
see from the ``btrfs subvolume list /`` command that ``snapper`` also
created a ``.snapshots`` subvolume. This subvolume will be used to
house the ``COW`` snapshots that are taken of the system.

Next, we'll workaround a bug_ that is causing snapper to have the wrong
SELinux context on the ``.snapshots`` directory::

    [root@localhost ~]# restorecon -v /.snapshots/
    restorecon reset /.snapshots context system_u:object_r:unlabeled_t:s0->system_u:object_r:snapperd_data_t:s0

.. _bug: https://bugzilla.redhat.com/show_bug.cgi?id=1247530

Finally, we'll add an entry to fstab so that regardless of what
subvolume we are actually booted in we will always be able to view
the ``.snapshots`` subvolume and all nested subvolumes (snapshots)::

    [root@localhost ~]# echo '/dev/vgroot/lvroot /.snapshots btrfs subvol=.snapshots 0 0' >> /etc/fstab
    

Taking Snapshots
----------------

OK, now that we have snapper installed and the ``.snapshots``
subvolume in ``/etc/fstab`` we can start creating snapshots::

    [root@localhost ~]# btrfs subvolume get-default /
    ID 5 (FS_TREE)
    [root@localhost ~]# snapper create --description "BigBang"
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                            | User | Cleanup | Description | Userdata
    -------+---+-------+---------------------------------+------+---------+-------------+---------
    single | 0 |       |                                 | root |         | current     |         
    single | 1 |       | Sat 23 Apr 2016 01:04:51 PM UTC | root |         | BigBang     |         
    [root@localhost ~]# btrfs subvolume list /
    ID 259 gen 64 top level 5 path .snapshots
    ID 260 gen 64 top level 259 path .snapshots/1/snapshot
    [root@localhost ~]# ls /.snapshots/1/snapshot/
    bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

We made our first snapshot called **BigBang** and then ran a ``btrfs
subvolume list /`` to view that a new snapshot was actually created.
Notice at the top of the output of the sections that we ran a ``btrfs
subvolume get-default /``. This outputs what the currently set *default
subvolume* is for the ``BTRFS`` filesystem. Right now we are booted
into the *root subvolume* but that will change as soon as we decide we
want to use one of the snapshots for rollback.

Since we took a snapshot let's go ahead and make some changes to the 
system by updating the kernel::

    [root@localhost ~]# dnf update -y kernel
    ...
    Complete!
    [root@localhost ~]# rpm -q kernel
    kernel-4.5.0-0.rc7.git0.2.fc24.x86_64
    kernel-4.5.2-300.fc24.x86_64
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                            | User | Cleanup | Description                   | Userdata
    -------+---+-------+---------------------------------+------+---------+-------------------------------+---------
    single | 0 |       |                                 | root |         | current                       |         
    single | 1 |       | Sat 23 Apr 2016 01:04:51 PM UTC | root |         | BigBang                       |         
    single | 2 |       | Sat 23 Apr 2016 01:08:18 PM UTC | root | number  | /usr/bin/dnf update -y kernel |

So we updated the kernel and the ``snapper`` ``dnf`` plugin automatically
created a snapshot for us. Let's reboot the system and see if the new kernel
boots properly::

    [root@localhost ~]# reboot 
    ...
    [dustymabe@media ~]$ ssh root@192.168.122.188 
    Warning: Permanently added '192.168.122.188' (ECDSA) to the list of known hosts.
    root@192.168.122.188's password: 
    Last login: Sat Apr 23 12:18:55 2016 from 192.168.122.1
    [root@localhost ~]# 
    [root@localhost ~]# uname -r
    4.5.2-300.fc24.x86_64

Rolling Back
------------

Say we don't like that new kernel. Let's go back to the earlier
snapshot we made::

    [root@localhost ~]# snapper rollback 1
    Creating read-only snapshot of current system. (Snapshot 3.)
    Creating read-write snapshot of snapshot 1. (Snapshot 4.)
    Setting default subvolume to snapshot 4.
    [root@localhost ~]# reboot


``snapper`` created a read-only snapshot of the current system and
then a new read-write subvolume based on the snapshot we wanted to
go back to. It then sets the *default subvolume* to be the newly created
read-write subvolume. After reboot you'll be in the newly created 
read-write subvolume and exactly back in the state you system was 
in at the time the snapshot was created.

In our case, after reboot we should now be booted into snapshot 4 as
indicated by the output of the ``snapper rollback`` command above and
we should be able to inspect information about all of the snapshots on
the system::

    [root@localhost ~]# btrfs subvolume get-default /
    ID 263 gen 87 top level 259 path .snapshots/4/snapshot
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                            | User | Cleanup | Description                   | Userdata
    -------+---+-------+---------------------------------+------+---------+-------------------------------+---------
    single | 0 |       |                                 | root |         | current                       |         
    single | 1 |       | Sat 23 Apr 2016 01:04:51 PM UTC | root |         | BigBang                       |         
    single | 2 |       | Sat 23 Apr 2016 01:08:18 PM UTC | root | number  | /usr/bin/dnf update -y kernel |         
    single | 3 |       | Sat 23 Apr 2016 01:17:43 PM UTC | root |         |                               |         
    single | 4 |       | Sat 23 Apr 2016 01:17:43 PM UTC | root |         |                               |         
    [root@localhost ~]# ls /.snapshots/
    1  2  3  4
    [root@localhost ~]# btrfs subvolume list /
    ID 259 gen 88 top level 5 path .snapshots
    ID 260 gen 81 top level 259 path .snapshots/1/snapshot
    ID 261 gen 70 top level 259 path .snapshots/2/snapshot
    ID 262 gen 80 top level 259 path .snapshots/3/snapshot
    ID 263 gen 88 top level 259 path .snapshots/4/snapshot

And the big test is to see if the change we made to the system was
actually reverted::

    [root@localhost ~]# uname -r
    4.5.0-0.rc7.git0.2.fc24.x86_64
    [root@localhost ~]# rpm -q kernel
    kernel-4.5.0-0.rc7.git0.2.fc24.x86_64

| Enjoy!
|
| Dusty
