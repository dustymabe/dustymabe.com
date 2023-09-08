---
title: 'Using virtiofs with libvirt/virt-install'
author: dustymabe
date: 2023-09-08
tags: [ libvirt virtiofs ]
published: true
---

Recently we
[switched](https://github.com/coreos/coreos-assembler/pull/3428)
our 9p filesystem usage in CoreOS Assembler to use
[virtiofs](https://virtio-fs.gitlab.io/).

This is the technology behind a lot of new lightweight container VM
technology like [kata-containers](https://katacontainers.io/) and
[libkrun](https://github.com/containers/libkrun), but can also be
easily used with [libvirt](https://libvirt.org/).

## Running as non-root using qemu:///session

Currently the virtiofs integration doesn't work as non-root via a
`qemu:///session` connection. There is an oustanding RFE for this
[upstream](https://gitlab.com/libvirt/libvirt/-/issues/535)
and [downstream](https://bugzilla.redhat.com/show_bug.cgi?id=2034630)
in RHEL that can be followed for updates.

## virtiosfs with virt-install

I typically use `virt-install` to automate creation of my libvirt virtual
machines. Using `virt-install` we can use the `--filesystem=` and
`--memorybacking=` parameters to get what we want. The
`--memorybacking=` parameter will add shared memory to the instance,
which is [required](https://libvirt.org/kbase/virtiofs.html#other-options-for-vhost-user-memory-setup)
for virtiofs.

Here is an example `virt-install` command to bring up a VM with
a virtiofs filesystem:

```
sudo virt-install --import --name virtiofs-tester                           \
    --accelerate --ram 4096 --vcpus 2 --autoconsole text                    \
    --os-variant fedora-unknown --network bridge=virbr0,model=virtio        \
    --disk size=10,backing_store=$PWD/Fedora-Cloud-Base-38-1.6.x86_64.qcow2 \
    --cloud-init=ssh-key=$PWD/id_rsa.pub                                    \
    --filesystem=/var/b/shared/,var-b-shared,driver.type=virtiofs           \
    --memorybacking=source.type=memfd,access.mode=shared
```

**NOTE:** In the future when this is [supported in a non-root user session](https://gitlab.com/libvirt/libvirt/-/issues/535) you should be able to remove the `sudo` from the command.

This will create libvirt XML with the following two key elements:

```
  <memoryBacking>
    <access mode="shared"/>
    <source type="memfd"/>
  </memoryBacking>
```

and

```
    <filesystem type="mount">
      <source dir="/var/b/shared/"/>
      <target dir="var-b-shared"/>
      <driver type="virtiofs"/>
    </filesystem>
```

**NOTE:** `var-b-shared` here is just a string that will be used to do the mount inside the guest. It can be a string representing where the user wants the filesystem to be mounted but it doesn't have to be.

Now inside the guest you can mount the filesystem with:

```
[dustymabe@media ~]$ ssh root@192.168.122.54
Warning: Permanently added '192.168.122.54' (ED25519) to the list of known hosts.
[root@localhost ~]# 
[root@localhost ~]# sudo mkdir -p /var/b/shared
[root@localhost ~]# sudo mount -t virtiofs var-b-shared /var/b/shared/
```

Success!

In order to make the mount persistent across reboots add it to the
`/fstab` via something like:

```
[root@localhost ~]# sudo tee -a /etc/fstab <<EOF 
var-b-shared /var/b/shared/ virtiofs defaults 0 2
EOF
```

And you're done.
