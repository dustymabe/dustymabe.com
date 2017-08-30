---
title: 'Atomic Host 101 Lab Part 2: Container Storage'
author: dustymabe
date: 2017-08-31
tags: [ fedora, atomic ]
published: true
---

# Introduction 

In [Part 1](/2017/08/30/atomic-host-101-lab-part-1-getting-familiar/)
of this series we learned a little about the technology behind Atomic
Host and how to interact with a deployed system. In this section we
will cover the **Configuring Storage for Containers** topic from the
outline in [Part 0](/2017/08/29/atomic-host-101-lab-part-0-preparation/).


# History of Container Storage

One of the early goals of Atomic Host was to be a good platform for
running containerized workloads. This is still a fundamental goal of
Atomic Host and certainly includes making sure that the container
runtime (currently the `docker` daemon) has proper storage
configuration such that it can get a balance of good performance and
stability.

For a long while the best option for Red Hat based operating systems 
was to use the `devicemapper` storage backend for docker. The benefits
were that the devicemapper backend was stable, decently performant, 
and had SELinux support. More recently, the `overlay2` backend has
emerged as a legitimate option because SELinux support has landed
and there are significant performance improvements over devicemapper.

However, most of the storage needs and original designs were centered
around devicemapper and the fact that the backend requires
there to be a separate dedicated block device that can be donated to
the dm thin-pool. This could be an actual physical block
device, or a LVM logical volume from an existing volume group.

# The container-storage-setup Tool

The need for a device to be dedicated to container storage prompted
the need for a tool, called [container-storage-setup](https://github.com/projectatomic/container-storage-setup)
(previously known as `docker-storage-setup`) to make this easy for spinning up
instances of a container host. Atomic Host has conveniently shipped
with extra space available on pre-built disk images so that
`container-storage-setup` could use it when configuring storage for
docker.

Since `container-storage-setup` gets executed automatically by
systemd when the `docker.service` starts, leveraging the tool is usually
as simple as populating the `/etc/sysconfig/docker-storage-setup` file
early in boot (i.e. cloud-init or some other mechanism)
with some config values that tell the utility what to do.

In order to investigate some of the options we have available take a
look at the existing contents of that file on the Atomic Host:

```nohighlight
[root@localhost ~]# cat /etc/sysconfig/docker-storage-setup
# Edit this file to override any configuration options specified in
# /usr/share/container-storage-setup/container-storage-setup.
#
# For more details refer to "man container-storage-setup"
STORAGE_DRIVER=overlay2
CONTAINER_ROOT_LV_NAME=docker-root-lv
CONTAINER_ROOT_LV_MOUNT_PATH=/var/lib/docker
GROWPART=true
```

As you can see from the contents of the file, in Fedora 26 we
have already moved on to setting overlay2 as the default storage
driver for the container runtime. In this case we are also defauting
to creating a new LV (`docker-root-lv`) and a filesystem (XFS) on top of
that LV to mount on `/var/lib/docker`. The overlay2 backend will then
run on top of that filesystem.

**NOTE:** *There are a lot of options that can be provided to the
          `container-storage-setup` tool. You can investigate them by checking
          out the `/usr/share/container-storage-setup/container-storage-setup` file.*

# Inspecting The Booted System

We just saw the contents of the `/etc/sysconfig/docker-storage-setup`
file. Let's check out the output from the `docker-storage-setup.service`
to see what happened when the system came up and the docker daemon was
started:

```nohighlight
[root@localhost ~]# systemctl status docker-storage-setup.service -o cat
● docker-storage-setup.service - Docker Storage Setup
   Loaded: loaded (/usr/lib/systemd/system/docker-storage-setup.service; enabled; vendor preset: disabled)
   Active: inactive (dead) since Mon 2017-08-28 00:15:50 UTC; 27min ago
 Main PID: 720 (code=exited, status=0/SUCCESS)

Starting Docker Storage Setup...
CHANGED: partition=2 start=616448 old: size=83269632 end=83886080 new: size=85366784,end=85983232
  Physical volume "/dev/vda2" changed
  1 physical volume(s) resized / 0 physical volume(s) not resized
  Logical volume "docker-root-lv" created.
Started Docker Storage Setup.
```

Looks like the root partition was extended and the `docker-root-lv` LV
was created. Although we don't explicitly see the output here it is
also true that an XFS filesystem was created on top of that and
storage options that specify `overlay2` were added to the 
`/etc/sysconfig/docker-storage` configuration file.

We can see the LV is mounted on `/var/lib/docker`:

```nohighlight
[root@localhost ~]# lsblk
NAME                          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda                           252:0    0   41G  0 disk
├─vda1                        252:1    0  300M  0 part /boot
└─vda2                        252:2    0 40.7G  0 part
  ├─atomicos-root             253:0    0   13G  0 lvm  /sysroot
  └─atomicos-docker--root--lv 253:1    0 15.1G  0 lvm  /sysroot/ostree/deploy/fedora-atomic/var/lib/docker
```

Also, if we query `docker` we can see that it is using the `overlay2`
*Storage Driver*.

```nohighlight
[root@localhost ~]# docker info 2>/dev/null | grep 'Storage Driver'
Storage Driver: overlay2
```


# Changing Storage Configuration

**NOTE:** *If you are going to change container storage on a system
          please be mindful that you will lose the container
          images/data that currently exist on your system. The Atomic
          CLI has `atomic storage import/export` to attempt to save
          and restore containers for this type of scenario.*

We can also use the `container-storage-setup` utility to change the
storage configuration on a system. Again, it is suggested that you
look at the `/usr/share/container-storage-setup/container-storage-setup` file
for an explanation of options that you can put in the
`/etc/sysconfig/docker-storage-setup` configuration file.

For example, if you want to switch from `overlay2` to `devicemapper`
you would need to change it so that `STORAGE_DRIVER=devicemapper`.
As an exercise, let's switch this system to the devicemapper backend.

We'll first stop docker, unmount the filesystem which was backing
the overlay2 driver, and also remove the logical volume that filesystem
was build on top of.


```nohighlight
[root@localhost ~]# systemctl stop docker
[root@localhost ~]# umount /var/lib/docker
[root@localhost ~]# lvremove /dev/atomicos/docker-root-lv
Do you really want to remove active logical volume atomicos/docker-root-lv? [y/n]: y
  Logical volume "docker-root-lv" successfully removed
```

Since we just unmounted and removed the LV behind `/var/lib/docker`
we need to remove the systemd mount unit that was configured 
to mount `/var/lib/docker`. Removing this file is like removing an
entry from the `/etc/fstab`.

```nohighlight
[root@localhost ~]# rm /etc/systemd/system/docker-storage-setup.service.wants/var-lib-docker.mount
[root@localhost ~]# systemctl daemon-reload
```

Next we'll remove the `/etc/sysconfig/docker-storage` file, which
has options to give to the docker daemon to tell it what storage
driver to use, and also we'll overwrite all settings in the 
`/etc/sysconfig/docker-storage-setup` so that `container-storage-setup` 
will know we want to use the `devicemapper` backend. We'll then run
`container-storage-setup` to create the devicemapper thin pool 
and populate a new `/etc/sysconfig/docker-storage` with options for
the docker daemon.

**NOTE:** *Some or all of these operations may be able to be done by
          the `atomic storage modify` command. Feel free to
          investigate that option.*

```nohighlight
[root@localhost ~]# rm /etc/sysconfig/docker-storage
[root@localhost ~]# echo 'STORAGE_DRIVER=devicemapper' > /etc/sysconfig/docker-storage-setup
[root@localhost ~]# /usr/bin/container-storage-setup
  Using default stripesize 64.00 KiB.
  Rounding up size to full physical extent 44.00 MiB
  Logical volume "docker-pool" created.
  Logical volume atomicos/docker-pool changed.
```

Now that this is done you can see thin LV that was set up in the
output from `lsblk` and `lvs`:

```nohighlight
[root@localhost ~]# lsblk
NAME                            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda                             252:0    0   41G  0 disk
├─vda1                          252:1    0  300M  0 part /boot
└─vda2                          252:2    0 40.7G  0 part
  ├─atomicos-root               253:0    0   13G  0 lvm  /sysroot
  ├─atomicos-docker--pool_tmeta 253:1    0   44M  0 lvm
  │ └─atomicos-docker--pool     253:3    0   11G  0 lvm
  └─atomicos-docker--pool_tdata 253:2    0   11G  0 lvm
    └─atomicos-docker--pool     253:3    0   11G  0 lvm
[root@localhost ~]# lvs
  LV          VG       Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  docker-pool atomicos twi-a-t--- 11.02g             0.00   0.09
  root        atomicos -wi-ao---- 12.93g
```

Now we can start docker and verify that the devicemapper backend is
being used:

```nohighlight
[root@localhost ~]# systemctl start docker
[root@localhost ~]# docker info 2>/dev/null | grep 'Storage Driver'
Storage Driver: devicemapper
```

To cap things off let's import a container image from our lab files
and run a container to see that new devicemapper objects are getting
created for this storage:

```nohighlight
[root@localhost ~]# atomic storage import --dir  /srv/localweb/containers/
Importing image: a16c8800bb14
7d4769f4070d: Loading layer [==================================================>] 242.5 MB/242.5 MB
25ca5f0393cd: Loading layer [==================================================>]   359 MB/359 MB
960139190bea: Loading layer [==================================================>] 71.77 MB/71.77 MB
Loaded image: registry.fedoraproject.org/f25/httpd:latest
Importing volumes
atomic import completed successfully
Would you like to cleanup (rm -rf /srv/localweb/containers/) the temporary directory [y/N]N
Please restart docker daemon for the changes to take effect
[root@localhost ~]#
[root@localhost ~]# docker run -d a16c8800bb14 sleep 600
b0509ea6c6b6811915f3f2d15a9fd344836f628a638d797683e7b27c4be84205
[root@localhost ~]#
[root@localhost ~]# lsblk
NAME                            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda                             252:0    0   41G  0 disk
├─vda1                          252:1    0  300M  0 part /boot
└─vda2                          252:2    0 40.7G  0 part
  ├─atomicos-root               253:0    0   13G  0 lvm  /sysroot
  ├─atomicos-docker--pool_tmeta 253:1    0   44M  0 lvm
  │ └─atomicos-docker--pool     253:3    0   11G  0 lvm
  │   └─docker-253:0-14918141-d748db4190b91666509effaabaa06c24d6e5ed836e5421ce914250e7eb1ac5a0
  │                             253:4    0   10G  0 dm   /var/lib/docker/devicemapper/mnt/d748db4190b916
  └─atomicos-docker--pool_tdata 253:2    0   11G  0 lvm
    └─atomicos-docker--pool     253:3    0   11G  0 lvm
      └─docker-253:0-14918141-d748db4190b91666509effaabaa06c24d6e5ed836e5421ce914250e7eb1ac5a0
                                253:4    0   10G  0 dm   /var/lib/docker/devicemapper/mnt/d748db4190b916
```

As the container runs (`sleep 600`) we can see the new devicemapper
mounts that were created for the container in the `lsblk` output.

# Part 2 Wrap Up

Part 2 of this lab has introduced us to Container Storage and the
necessity for the `container-storage-setup` tool. We also inspected
how the storage gets configured on an Atomic Host and switched the
storage from one storage backend to another. In the
[next lab](/2017/09/01/atomic-host-101-lab-part-3-rebase-upgrade-rollback/)
we'll cover rebase, upgrade and rollback for Atomic Host as well as some
basic methods for viewing OSTree commit history and inspecting changes
to a running system.
