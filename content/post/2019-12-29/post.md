---
title: "Fedora BTRFS+Snapper - The Fedora 31 Edition"
tags: [ fedora, grub, btrfs, snapper ]
date: "2019-12-29"
published: true
---

# History

It's almost 2020. Fedora 31 came out a month back and I'm just getting 
around to converting my desktop system to Fedora 31. As mentioned before,
for my laptop systems I've moved on to 
[Fedora Silverblue](https://silverblue.fedoraproject.org/). As I
continue to containerize my workflows I'm moving more and more of my
daily workflows into [Flatpaks](https://github.com/flatpak/flatpak) from
the Fedora registry, pet containers (via [toolbox](https://github.com/containers/toolbox/))
and, single purpose containers. As I continue to convert my workflows into
containers I'll stick with the BTRFS+snapper setup for my desktop
system, which still has the benefits of being able to snapshot and rollback 
the entire system by leveraging `BTRFS` snapshots, and a tool called `snapper`.

In the past I have documented this setup and all the steps I took in
detail for Fedora 22
([part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/)
 and
 [part2](/2015/07/19/fedora-btrfssnapper-part-2-full-system-snapshotrollback/)),
[24](/2016/04/23/fedora-btrfssnapper-the-fedora-24-edition/),
[25](/2017/02/12/fedora-btrfssnapper-the-fedora-25-edition/),
[27](/2017/12/17/fedora-btrfssnapper-the-fedora-27-edition/),
and [29](/2019/01/06/fedora-btrfs-snapper---the-fedora-29-edition/).
This is a condensed continuation of those posts for Fedora 31. 

# Setting up System with LUKS + LVM + BTRFS

The manual steps for setting up the system are detailed in the 
[part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/)
blog post from Fedora 22. This time around I have created a 
[script](/2019-01-06/script.sh) that will quickly
configure the system with `LUKS` + `LVM` + `BTRFS`. The script
will need to be run in an Anaconda environment just like the manual
steps were done in 
[part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/) the first time.

You can easily enable `ssh` access to your Anaconda booted machine by
adding `inst.sshd` to the kernel command line arguments. After 
booting up you can `scp` the script over and then execute it to
build the system. Please read over the script and modify it to your
liking.

Alternatively, for an automated install I have embedded that same
script into a [kickstart file](/2019-12-29/ks.cfg) that you can use.
The kickstart file doesn't really leverage Anaconda at all because it simply runs a 
`%pre` script and then reboots the box. It's more or less like having
Anaconda run a bash script, but allows you to do it in an automated way.
None of the kickstart directives at the top of the kickstart file actually get used. 

Note that this time I did run into a problem because the default for
LUKS now is to use the version 2 of the header format.
[GRUB2 doesn't support this yet](https://savannah.gnu.org/bugs/?55093)
so I had to change the command to specify `--type luks1`.


# Installing and Configuring Snapper

*NOTE*: systemd creates some btrfs subvolumes automatically. They have
        been omitted from the logged output from commands below.

Let's configure the system for doing snapshots. I still want
to be able to track how much size each snapshot has taken so 
I'll go ahead and enable `quota` support on `BTRFS`. I covered how 
to do this in a 
[previous post](/2013/09/22/btrfs-how-big-are-my-snapshots/).

```nohighlight
[root@localhost ~]# btrfs quota enable /
[root@localhost ~]# btrfs qgroup show /
qgroupid         rfer         excl 
--------         ----         ---- 
0/5           1.33GiB      1.33GiB
```

Next up is installing `snapper`. I am also going to
install the `dnf` plugin for snapper so that rpm transactions will
automatically get snapshotted:

```nohighlight
[root@localhost ~]# dnf install -y snapper python3-dnf-plugins-extras-snapper
...
Complete!
```

Use `snapper` command to create a configuration for
`BTRFS` filesystem mounted at `/`:

```nohighlight
[root@localhost ~]# snapper --config=root create-config /
```

Now we can look at the snapshot setup and the current configuration:

```nohighlight
[root@localhost ~]# snapper --config=root create-config /
[root@localhost ~]# snapper ls
 # | Type   | Pre # | Date | User | Used Space | Cleanup | Description | Userdata
---+--------+-------+------+------+------------+---------+-------------+---------
0  | single |       |      | root |            |         | current     |         
[root@localhost ~]# snapper list-configs
Config | Subvolume
-------+----------
root   | /        
[root@localhost ~]# btrfs subvolume list /
ID 262 gen 1811 top level 5 path .snapshots
```

We can see from the `btrfs subvolume list /` command that 
`snapper` also created a `.snapshots` subvolume. This subvolume
will be used to house the `COW` snapshots that are taken of the system.

Next, we'll add an entry to fstab so that regardless of what
subvolume we are actually booted in we will always be able to view
the `.snapshots` subvolume and all nested subvolumes (snapshots):

```nohighlight
[root@localhost ~]# echo '/dev/vgroot/lvroot /.snapshots btrfs subvol=.snapshots 0 0' >> /etc/fstab
```
    

Taking Snapshots
----------------

OK, now that we have snapper installed and the `.snapshots`
subvolume in `/etc/fstab` we can start creating snapshots:

```nohighlight
[root@localhost ~]# btrfs subvolume get-default /
ID 5 (FS_TREE)
[root@localhost ~]# snapper create --description "BigBang"
[root@localhost ~]# snapper ls
 # | Type   | Pre # | Date                            | User | Used Space | Cleanup | Description | Userdata
---+--------+-------+---------------------------------+------+------------+---------+-------------+---------
0  | single |       |                                 | root |            |         | current     |         
1  | single |       | Sun 29 Dec 2019 05:49:25 PM UTC | root | 120.00 KiB |         | BigBang     |         
[root@localhost ~]# btrfs subvolume list /
ID 262 gen 1823 top level 5 path .snapshots
ID 263 gen 1820 top level 262 path .snapshots/1/snapshot
[root@localhost ~]# ls /.snapshots/1/snapshot/
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```

We made our first snapshot called **BigBang** and then ran a `btrfs
subvolume list /` to view that a new snapshot was actually created.
Notice at the top of the output of the sections that we ran a `btrfs
subvolume get-default /`. This outputs what the currently set **default
subvolume** is for the `BTRFS` filesystem. Right now we are booted
into the **root subvolume** but that will change as soon as we decide we
want to use one of the snapshots for rollback.

Since we took a snapshot let's go ahead and make some changes to the 
system by updating the kernel:

```nohighlight
[root@localhost ~]# dnf update -y kernel
...
Complete!
[root@localhost ~]# rpm -q kernel
kernel-5.3.7-301.fc31.x86_64
kernel-5.3.16-300.fc31.x86_64
[root@localhost ~]# snapper ls
 # | Type   | Pre # | Date                            | User | Used Space | Cleanup | Description                   | Userdata
---+--------+-------+---------------------------------+------+------------+---------+-------------------------------+---------
0  | single |       |                                 | root |            |         | current                       |         
1  | single |       | Sun 29 Dec 2019 05:49:25 PM UTC | root |   8.82 MiB |         | BigBang                       |         
2  | pre    |       | Sun 29 Dec 2019 05:51:24 PM UTC | root |   8.96 MiB | number  | /usr/bin/dnf update -y kernel |         
3  | post   |     2 | Sun 29 Dec 2019 05:52:01 PM UTC | root | 640.00 KiB | number  | /usr/bin/dnf update -y kernel |
```

So we updated the kernel and the `snapper` `dnf` plugin automatically
created a `pre` and `post` snapshot for us. Let's reboot the system and 
see if the new kernel boots properly:

```nohighlight
[root@localhost ~]# reboot
Connection to 192.168.122.183 closed by remote host.
Connection to 192.168.122.183 closed.
[dustymabe@media ~]$ ssh root@192.168.122.183
root@192.168.122.183's password: 
Last login: Sun Dec 29 17:43:16 2019 from 192.168.122.1
[root@localhost ~]# uname -r
5.3.16-300.fc31.x86_64
```

Rolling Back
------------

Want to go back to the earlier snapshot? No problem!

```nohighlight
[root@localhost ~]# snapper rollback 1
Creating read-only snapshot of current system. (Snapshot 4.)
Creating read-write snapshot of snapshot 1. (Snapshot 5.)
Setting default subvolume to snapshot 5.
[root@localhost ~]# reboot
```


`snapper` created a read-only snapshot of the current system and
then a new read-write subvolume based on the snapshot we wanted to
go back to. It then sets the **default subvolume** to be the newly created
read-write subvolume. After reboot you'll be in the newly created 
read-write subvolume and exactly back in the state you system was 
in at the time the snapshot was created.

In our case, after reboot we should now be booted into snapshot 5 as
indicated by the output of the `snapper rollback` command above and
we should be able to inspect information about all of the snapshots on
the system:

```nohighlight
[root@localhost ~]# btrfs subvolume get-default /
ID 267 gen 1913 top level 262 path .snapshots/5/snapshot
[root@localhost ~]# snapper ls
 # | Type   | Pre # | Date                            | User | Used Space | Cleanup | Description                   | Userdata     
---+--------+-------+---------------------------------+------+------------+---------+-------------------------------+--------------
0  | single |       |                                 | root |            |         | current                       |              
1  | single |       | Sun 29 Dec 2019 05:49:25 PM UTC | root |   1.89 MiB |         | BigBang                       |              
2  | pre    |       | Sun 29 Dec 2019 05:51:24 PM UTC | root |   8.96 MiB | number  | /usr/bin/dnf update -y kernel |              
3  | post   |     2 | Sun 29 Dec 2019 05:52:01 PM UTC | root |   4.66 MiB | number  | /usr/bin/dnf update -y kernel |              
4  | single |       | Sun 29 Dec 2019 06:00:11 PM UTC | root |   1.68 MiB | number  | rollback backup               | important=yes
5* | single |       | Sun 29 Dec 2019 06:00:11 PM UTC | root |  46.23 MiB |         |                               |              
[root@localhost ~]# ls /.snapshots/
1  2  3  4  5
[root@localhost ~]# btrfs subvolume list /
ID 262 gen 1914 top level 5 path .snapshots
ID 263 gen 1886 top level 262 path .snapshots/1/snapshot
ID 264 gen 1829 top level 262 path .snapshots/2/snapshot
ID 265 gen 1847 top level 262 path .snapshots/3/snapshot
ID 266 gen 1886 top level 262 path .snapshots/4/snapshot
ID 267 gen 1916 top level 262 path .snapshots/5/snapshot
```

And the big test is to see if the change we made to the system was
actually reverted:

```nohighlight
[root@localhost ~]# uname -r
5.3.7-301.fc31.x86_64
[root@localhost ~]# rpm -q kernel
kernel-5.3.7-301.fc31.x86_64
```

It worked!
