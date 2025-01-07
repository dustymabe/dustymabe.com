---
title: "Fedora BTRFS+Snapper - The Fedora 41 Edition"
tags: [ fedora, grub, btrfs, snapper ]
date: "2025-01-07"
published: true
---

# History

It's a new year and it has been 5 years since the last time I updated
this blog post series. This time I'm updating to Fedora 41 and also
bringing forward a lot of changes I've made over the last 5 years.

As [mentioned previously](/2019/12/29/fedora-btrfs-snapper---the-fedora-31-edition/)
for now I'm using [Fedora Silverblue](https://silverblue.fedoraproject.org/)
on my laptop systems and continuing with a BTRFS+snapper setup for my desktop.
This series describes the BTRFS+snapper setup.

In the past I have documented this setup and all the steps I took in
detail for Fedora 22
([part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/)
 and
 [part2](/2015/07/19/fedora-btrfssnapper-part-2-full-system-snapshotrollback/)),
[24](/2016/04/23/fedora-btrfssnapper-the-fedora-24-edition/),
[25](/2017/02/12/fedora-btrfssnapper-the-fedora-25-edition/),
[27](/2017/12/17/fedora-btrfssnapper-the-fedora-27-edition/),
[29](/2019/01/06/fedora-btrfs-snapper-the-fedora-29-edition/)
and [31](/2019/12/29/fedora-btrfs-snapper-the-fedora-31-edition/).
This is a condensed continuation of those posts for Fedora 41, but
there are a few changes I've made.

The biggest change from 
[part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/)
being that now, instead of using the MBR for GRUB
I'm using EFI so I can take advantage of
[Secure Boot](https://en.wikipedia.org/wiki/UEFI#Secure_Boot).
Now, I still wanted to encrypt my entire hard drive so I opted use a second
disk (i.e. a small USB key or similar) to hold and EFI/GRUB configuration
that instructs the computer to decrypt the main disk and then load
a GRUB config file from there.

The EFI files and pointer GRUB config on the USB key doesn't need to
be updated as it will always just point to the main config on the main
disk.

# Setting up System with LUKS + LVM + BTRFS

The updated script/kickstart for quickly configuring the 
`LUKS` + `LVM` + `BTRFS` with `EFI` system can be found at the
following links:

- [script.sh](/2025-01-07/script.sh)
- [ks.cfg](/2025-01-07/ks.cfg)

The script will need to be run in an Anaconda environment just like the manual
steps were done in 
[part1](/2015/07/14/fedora-btrfssnapper-part-1-system-preparation/) the first time.

You can easily enable `ssh` access to your Anaconda booted machine by
adding `inst.sshd` to the kernel command line arguments. After 
booting up you can `scp` the script over and then execute it to
build the system. Please read over the script and modify it to your
liking.

Alternatively, for an automated install you can use the kickstart
file. The kickstart file doesn't really leverage Anaconda at all because it simply runs a 
`%pre` script and then reboots the box. It's more or less like having
Anaconda run a bash script, but allows you to do it in an automated way.
None of the kickstart directives at the top of the kickstart file actually get used. 

# Installing and Configuring Snapper

Let's configure the system for doing snapshots. I still want
to be able to track how much size each snapshot has taken so 
I'll go ahead and enable `quota` support on `BTRFS`. I covered how 
to do this in a 
[previous post](/2013/09/22/btrfs-how-big-are-my-snapshots/).

```nohighlight
root@fedora:~# btrfs quota enable /
root@fedora:~# btrfs qgroup show /
Qgroupid    Referenced    Exclusive   Path 
--------    ----------    ---------   ---- 
0/5            1.29GiB      1.29GiB   <toplevel>
```

Next up is installing `snapper` and configuring DNF to create
snapshots when transactions occur. In previous iterations the 
`python3-dnf-plugins-extras-snapper` package was installed to pull
in the snapper `dnf` plugin, but currently for `dnf5` there
[is no snapper plugin](https://github.com/rpm-software-management/dnf5/issues/702#issuecomment-1635475131),
but there is a workaround using the actions plugin so we'll install that
and configure it for now.


```nohighlight
root@fedora:~# dnf install -y snapper libdnf5-plugin-actions
...
Complete!
```

Now that the `snapper` and the actions plugin are installed we can
configure the plugin to create snapshots. This example is taken 
(and modified slightly) from the bottom of
[this](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html#an-example-actions-file) example 

```
root@fedora:~# cat <<'EOF' > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# The next two actions emulate the DNF4 snapper plugin. It uses the "snapper" command-line proram.

# Creates pre snapshot before the transaction and stores the snapshot number in the "tmp.snapper_pre_number" variable.
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_desc=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -p\ -d\ '${tmp.snapper_desc}')"

# If the variable "tmp.snapper_pre_number" exists, it creates post snapshot after the transaction and removes the tmp variables
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.snapper_desc}";\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.snapper_desc
EOF
```

Use `snapper` command to create a configuration for
`BTRFS` filesystem mounted at `/`:

```nohighlight
root@fedora:~# snapper --config=root create-config /
```

Now we can look at the snapshot setup and the current configuration:

```nohighlight
root@fedora:~# snapper ls
# │ Type   │ Pre # │ Date │ User │ Used Space │ Cleanup │ Description │ Userdata
──┼────────┼───────┼──────┼──────┼────────────┼─────────┼─────────────┼─────────
0 │ single │       │      │ root │            │         │ current     │

root@fedora:~# snapper list-configs
Config │ Subvolume
───────┼──────────
root   │ /

root@fedora:~# btrfs subvolume list /
ID 256 gen 33 top level 5 path .snapshots
```

We can see from the `btrfs subvolume list /` command that 
`snapper` also created a `.snapshots` subvolume. This subvolume
will be used to house the `COW` snapshots that are taken of the system.

Next, we'll add an entry to fstab so that regardless of what
subvolume we are actually booted in we will always be able to view
the `.snapshots` subvolume and all nested subvolumes (snapshots):

```nohighlight
root@fedora:~# echo '/dev/vgroot/root /.snapshots btrfs subvol=.snapshots 0 0' >> /etc/fstab
```
    

Taking Snapshots
----------------

OK, now that we have snapper installed and the `.snapshots`
subvolume in `/etc/fstab` we can start creating snapshots:

```nohighlight
root@fedora:~# btrfs subvolume get-default /
ID 5 (FS_TREE)

root@fedora:~# snapper create --description "BigBang"

root@fedora:~# snapper ls
# │ Type   │ Pre # │ Date                     │ User │ Used Space │ Cleanup │ Description │ Userdata
──┼────────┼───────┼──────────────────────────┼──────┼────────────┼─────────┼─────────────┼─────────
0 │ single │       │                          │ root │            │         │ current     │
1 │ single │       │ Tue Jan  7 19:50:53 2025 │ root │ 100.00 KiB │         │ BigBang     │

root@fedora:~# btrfs subvolume list /
ID 256 gen 40 top level 5 path .snapshots
ID 257 gen 39 top level 256 path .snapshots/1/snapshot

root@fedora:~# ls /.snapshots/1/snapshot/
afs  bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
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

root@fedora:~# dnf update -y kernel
...
Complete!

root@fedora:~# rpm -q kernel
kernel-6.11.4-301.fc41.x86_64
kernel-6.12.7-200.fc41.x86_64

root@fedora:~# snapper ls
# │ Type   │ Pre # │ Date                     │ User │ Used Space │ Cleanup │ Description          │ Userdata
──┼────────┼───────┼──────────────────────────┼──────┼────────────┼─────────┼──────────────────────┼─────────
0 │ single │       │                          │ root │            │         │ current              │
1 │ single │       │ Tue Jan  7 19:50:53 2025 │ root │ 540.00 KiB │         │ BigBang              │
2 │ pre    │       │ Tue Jan  7 19:52:05 2025 │ root │ 452.00 KiB │         │ dnf update -y kernel │
3 │ post   │     2 │ Tue Jan  7 19:52:42 2025 │ root │  14.19 MiB │         │ dnf update -y kernel │
```

So we updated the kernel and the `snapper` `dnf` plugin automatically
created a `pre` and `post` snapshot for us. Let's reboot the system and 
see if the new kernel boots properly:

```nohighlight
root@fedora:~# reboot 
root@fedora:~# Connection to 192.168.122.98 closed by remote host.
Connection to 192.168.122.98 closed.

[dustymabe@media ~]$ ssh root@192.168.122.98
Warning: Permanently added '192.168.122.98' (ED25519) to the list of known hosts.
Last login: Tue Jan  7 19:47:48 2025 from 192.168.122.1

root@fedora:~# uname -r
6.12.7-200.fc41.x86_64
```

Rolling Back
------------

Want to go back to the earlier snapshot? No problem!

```nohighlight
root@fedora:~# snapper --ambit classic rollback 1
Ambit is classic.
Creating read-only snapshot of current system. (Snapshot 4.)
Creating read-write snapshot of snapshot 1. (Snapshot 5.)
Setting default subvolume to snapshot 5.
root@fedora:~# reboot
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
root@fedora:~# btrfs subvolume get-default /
ID 261 gen 60 top level 256 path .snapshots/5/snapshot

root@fedora:~# snapper ls
 # │ Type   │ Pre # │ Date                     │ User │ Used Space │ Cleanup │ Description          │ Userdata
───┼────────┼───────┼──────────────────────────┼──────┼────────────┼─────────┼──────────────────────┼──────────────
0  │ single │       │                          │ root │            │         │ current              │
1  │ single │       │ Tue Jan  7 19:50:53 2025 │ root │ 232.00 KiB │         │ BigBang              │
2  │ pre    │       │ Tue Jan  7 19:52:05 2025 │ root │ 452.00 KiB │         │ dnf update -y kernel │
3  │ post   │     2 │ Tue Jan  7 19:52:42 2025 │ root │  17.55 MiB │         │ dnf update -y kernel │
4  │ single │       │ Tue Jan  7 19:55:55 2025 │ root │   1.88 MiB │ number  │ rollback backup      │ important=yes
5* │ single │       │ Tue Jan  7 19:55:55 2025 │ root │   8.86 MiB │         │ writable copy of #1  │

root@fedora:~# ls /.snapshots/
1  2  3  4  5

root@fedora:~# btrfs subvolume list /
ID 256 gen 64 top level 5 path .snapshots
ID 257 gen 60 top level 256 path .snapshots/1/snapshot
ID 258 gen 45 top level 256 path .snapshots/2/snapshot
ID 259 gen 48 top level 256 path .snapshots/3/snapshot
ID 260 gen 59 top level 256 path .snapshots/4/snapshot
ID 261 gen 66 top level 256 path .snapshots/5/snapshot
```

And the big test is to see if the change we made to the system was
actually reverted:

```nohighlight
root@fedora:~# uname -r
6.11.4-301.fc41.x86_64

root@fedora:~# rpm -q kernel
kernel-6.11.4-301.fc41.x86_64
```

Yay. I'm happy to see this is still working as expected!
