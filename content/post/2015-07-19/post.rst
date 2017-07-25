
.. Fedora BTRFS+Snapper PART 2: Full System Snapshot/Rollback
.. ==========================================================

History
-------

In `part 1`_ of this series I discussed why I desired a computer setup where I
can do full system snapshots so I could seamlessly roll back at will.
I also gave an overview of how I went about setting up a system so it
could take advantage of ``BTRFS`` and ``snapper`` to do full system
snapshotting and recovery. In this final post of the series I will
give an overview of how to get ``snapper`` installed and configured on
the system and walk through using it to do a rollback.

.. _part 1: http://dustymabe.com/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/


Installing and Configuring Snapper
----------------------------------

First things first, as part of this whole setup I want to be able to
tell how much space each one of my snapshots are taking up. I covered
how to do this in a `previous post`_, but the way you do it is by
enabled ``quota`` on the ``BTRFS`` filesystem::

    [root@localhost ~]# btrfs quota enable /      
    [root@localhost ~]# 
    [root@localhost ~]# btrfs subvolume list /
    ID 258 gen 50 top level 5 path var/lib/machines
    [root@localhost ~]# btrfs qgroup show /
    WARNING: Rescan is running, qgroup data may be incorrect
    qgroupid         rfer         excl 
    --------         ----         ---- 
    0/5         975.90MiB    975.90MiB 
    0/258        16.00KiB     16.00KiB

.. _previous post: http://dustymabe.com/2013/09/22/btrfs-how-big-are-my-snapshots/

You can see from the output that we currently have two subvolumes. One
of them is the *root subvolume* while the other is a subvolume
automatically created by ``systemd`` for ``systemd-nspawn`` container
images. 

Now that we have quota enabled let's get ``snapper`` installed and
configured::

    [root@localhost ~]# dnf install -y snapper
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
    [root@localhost ~]#
    [root@localhost ~]# btrfs subvolume list /
    ID 258 gen 50 top level 5 path var/lib/machines
    ID 260 gen 83 top level 5 path .snapshots

So we used the ``snapper`` command to create a configuration for
``BTRFS`` filesystem mounted at ``/``. As part of this process we can
see from the ``btrfs subvolume list /`` command that ``snapper`` also
created a ``.snapshots`` subvolume. This subvolume will be used to
house the ``COW`` snapshots that are taken of the system.

The next thing we want to do is add an entry to ``fstab`` to make it
so that regardless of what subvolume we are actually booted into we
will always be able to view the ``.snapshots`` subvolume and all
nested subvolumes (snapshots)::

    [root@localhost ~]# echo '/dev/vgroot/lvroot /.snapshots btrfs subvol=.snapshots 0 0' >> /etc/fstab
    

Taking Snapshots
----------------

OK, now that we have snapper installed and the ``.snapshots``
subvolume in ``/etc/fstab`` we can start creating snapshots::

    [root@localhost ~]# btrfs subvolume get-default /
    ID 5 (FS_TREE)
    [root@localhost ~]# snapper create --description "BigBang"
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                     | User | Cleanup | Description | Userdata
    -------+---+-------+--------------------------+------+---------+-------------+---------
    single | 0 |       |                          | root |         | current     |         
    single | 1 |       | Tue Jul 14 23:07:42 2015 | root |         | BigBang     |
    [root@localhost ~]# 
    [root@localhost ~]# btrfs subvolume list /
    ID 258 gen 50 top level 5 path var/lib/machines
    ID 260 gen 90 top level 5 path .snapshots
    ID 261 gen 88 top level 260 path .snapshots/1/snapshot
    [root@localhost ~]# 
    [root@localhost ~]# ls /.snapshots/1/snapshot/
    bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

We made our first snapshot called **BigBang** and then ran a ``btrfs
subvolume list /`` to view that a new snapshot was actually created.
Notice at the top of the output of the sections that we ran a ``btrfs
subvolume get-default /``. This outputs what the currently set *default
subvolume* is for the ``BTRFS`` filesystem. Right now we are booted
into the *root subvolume* but that will change as soon as we decide we
want to use one of the snapshots for rollback.

Since we took a snapshot let's go ahead and make some changes to the system::

    [root@localhost ~]# dnf install -y htop
    [root@localhost ~]# rpm -q htop
    htop-1.0.3-4.fc22.x86_64
    [root@localhost ~]# 
    [root@localhost ~]# snapper status 1..0  | grep htop
    +..... /usr/bin/htop
    +..... /usr/share/doc/htop
    +..... /usr/share/doc/htop/AUTHORS
    +..... /usr/share/doc/htop/COPYING
    +..... /usr/share/doc/htop/ChangeLog
    +..... /usr/share/doc/htop/README
    +..... /usr/share/man/man1/htop.1.gz
    +..... /usr/share/pixmaps/htop.png
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/checksum_data
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/checksum_type
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/command_line
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/from_repo
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/installed_by
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/reason
    +..... /var/lib/dnf/yumdb/h/2cd64300c204b0e1ecc9ad185259826852226561-htop-1.0.3-4.fc22-x86_64/releasever

So from this we installed ``htop`` and then compared the current running
system (``0``) with snapshot ``1``.


Rolling Back
------------

Now that we have taken a previous snapshot and have since made a
change to the system we can use the ``snapper rollback`` functionality
to get back to the state the system was in before we made the change.
Let's do the rollback to get back to the snapshot ``1`` **BigBang** state::

    [root@localhost ~]# snapper rollback 1
    Creating read-only snapshot of current system. (Snapshot 2.)
    Creating read-write snapshot of snapshot 1. (Snapshot 3.)
    Setting default subvolume to snapshot 3.
    [root@localhost ~]# reboot

As part of the rollback process you specify to ``snapper`` which
snapshot you want to go back to. It then creates a read-only snapshot
of the current system (in case you change your mind and want to get
back to where you currently are) and then a new read-write subvolume 
based on the snapshot you specified to go back to. It then sets the 
*default subvolume* to be the newly created read-write subvolume it
just created. After a reboot you will be booted into the new
read-write subvolume and your state should be exactly as it was at the
time you made the original snapshot.

In our case, after reboot we should now be booted into snapshot 3 as
indicated by the output of the ``snapper rollback`` command above and
we should be able to inspect information about all of the snapshots on
the system::

    [root@localhost ~]# btrfs subvolume get-default /
    ID 263 gen 104 top level 260 path .snapshots/3/snapshot
    [root@localhost ~]# 
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                     | User | Cleanup | Description | Userdata
    -------+---+-------+--------------------------+------+---------+-------------+---------
    single | 0 |       |                          | root |         | current     |         
    single | 1 |       | Tue Jul 14 23:07:42 2015 | root |         | BigBang     |         
    single | 2 |       | Tue Jul 14 23:14:12 2015 | root |         |             |         
    single | 3 |       | Tue Jul 14 23:14:12 2015 | root |         |             |         
    [root@localhost ~]# 
    [root@localhost ~]# ls /.snapshots/
    1  2  3
    [root@localhost ~]# btrfs subvolume list /
    ID 258 gen 50 top level 5 path var/lib/machines
    ID 260 gen 100 top level 5 path .snapshots
    ID 261 gen 98 top level 260 path .snapshots/1/snapshot
    ID 262 gen 97 top level 260 path .snapshots/2/snapshot
    ID 263 gen 108 top level 260 path .snapshots/3/snapshot

And the big test is to see if the change we made to the system was
actually reverted::

    [root@localhost ~]# rpm -q htop
    package htop is not installed

Bliss!!

Now in my case I like to have more descriptive notes on my snapshots
so I'll go back now and give some notes for snapshots 2 and 3::

    [root@localhost ~]# snapper modify --description "installed htop" 2
    [root@localhost ~]# snapper modify --description "rollback to 1 - read/write" 3 
    [root@localhost ~]# 
    [root@localhost ~]# snapper ls
    Type   | # | Pre # | Date                     | User | Cleanup | Description                | Userdata
    -------+---+-------+--------------------------+------+---------+----------------------------+---------
    single | 0 |       |                          | root |         | current                    |         
    single | 1 |       | Tue Jul 14 23:07:42 2015 | root |         | BigBang                    |         
    single | 2 |       | Tue Jul 14 23:14:12 2015 | root |         | installed htop             |         
    single | 3 |       | Tue Jul 14 23:14:12 2015 | root |         | rollback to 1 - read/write |


We can also see how much space (shared and exclusive each of the
snapshots are taking up::

    [root@localhost ~]# btrfs qgroup show / 
    WARNING: Qgroup data inconsistent, rescan recommended
    qgroupid         rfer         excl 
    --------         ----         ---- 
    0/5           1.08GiB      7.53MiB 
    0/258        16.00KiB     16.00KiB 
    0/260        16.00KiB     16.00KiB 
    0/261         1.07GiB      2.60MiB 
    0/262         1.07GiB    740.00KiB 
    0/263         1.08GiB     18.91MiB

Now that is useful info so you can know how much space you will be
recovering when you delete snapshots in the future.



Updating The Kernel
-------------------

I mentioned in `part 1`_ that I had to get a special rebuild of
``GRUB`` with some patches from the ``SUSE`` guys in order to get
booting from the default subvolume to work. This was all needed so
that I can update the kernel as normal and have the ``GRUB`` files that
get used be the ones that are in the actual subvolume I am currently
using. So let's test it out by doing a full system update (including 
a kernel update):: 


    [root@localhost ~]# dnf update -y
    ...
    Install    8 Packages
    Upgrade  173 Packages
    ...
    Complete!
    [root@localhost ~]# rpm -q kernel
    kernel-4.0.4-301.fc22.x86_64
    kernel-4.0.7-300.fc22.x86_64
    [root@localhost ~]# 
    [root@localhost ~]# btrfs qgroup show /
    WARNING: Qgroup data inconsistent, rescan recommended
    qgroupid         rfer         excl 
    --------         ----         ---- 
    0/5           1.08GiB      7.53MiB 
    0/258        16.00KiB     16.00KiB 
    0/260        16.00KiB     16.00KiB 
    0/261         1.07GiB     11.96MiB 
    0/262         1.07GiB    740.00KiB 
    0/263         1.19GiB    444.35MiB

So we did a full system upgrade that upgraded 173 packages and
installed a few others. We can see now that the current subvolume 
(snapshot ``3`` with ID ``263``) now has 444MiB of exclusive data.
This makes sense since all of the other snapshots were from before the
full system update.

Let's create a new snapshot that represents the state of the system
right after we did the full system update and then reboot::

    [root@localhost ~]# snapper create --description "full system upgrade"
    [root@localhost ~]# reboot

After reboot we can now check to see if we have properly booted the
recently installed kernel::

    [root@localhost ~]# rpm -q kernel
    kernel-4.0.4-301.fc22.x86_64
    kernel-4.0.7-300.fc22.x86_64
    [root@localhost ~]# uname -r
    4.0.7-300.fc22.x86_64

Bliss again. Yay! And I'm Done. 

| Enjoy!
|
| Dusty
