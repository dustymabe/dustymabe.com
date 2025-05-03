---
title: 'virt-install: boot from specific kernel/initrd just for install'
author: dustymabe
date: 2020-01-30
tags: [ fedora, libvirt, virsh, virt-install ]
draft: false
---

# Introduction

For some time now with
[virt-install](https://www.mankier.com/1/virt-install)
(developed under [virt-manager](https://virt-manager.org/))
you have been able to specify a kernel and initial ramdisk to
start a VM with. The only problem is that the VM will always
start with that kernel/initrd (unless you change the definition
manually). If you are rapidly testing operating system installations
this can be problematic.

On the one hand, providing the kernel/initrd allows one to automate
the install process from a Linux terminal, or even a script, by
specifying the kernel/initrd and also the kernel command line options.
However, it only gives us half the picture, because you'd then have to
hand edit the libvirt definition of the machine to see if the
installed machine was viable, **OR** you'd be lazy and just throw away
the installed machine and assume it was good because the installation
process finished without error; **BAD**.

When I was going through and testing the first iteration of the
[coreos-installer](https://github.com/coreos/coreos-installer/commit/a32b8e2)
I resorted to creating my own `.treeinfo` file in order to
workaround the shortcoming mentioned above. As a result of this I 
decided to
[file a feature request in `virt-install`](https://bugzilla.redhat.com/show_bug.cgi?id=1677425)
to support this narrow, but useful use case of being able to specify
a kernel/initrd and kernel arguments just for the install of a virtual
machine. Cole Robinson and team were gracious enough to implement this
feature request and now we have it in `virt-manager` 2.2.0 and later.

Let's try it out!

# Booting from Kernel/Initrd for Install


The way this was implemented is by utilizing sub argments to the
`--install` option of `virt-install`. You can see the `kernel`,
`initrd` and `kernel_args*` arguments from the help output:


```nohighlight
$ virt-install --install help
--install options:
  clearxml
  bootdev
  initrd
  kernel
  kernel_args
  kernel_args_overwrite
  no_install
  os
```

Putting it all together we can call `virt-install` with either a local
kernel/initrd or a remote kernel/initrd that can be accessed via
HTTP(S). Here is an example that uses a remote kernel/initrd and does
an install of Fedora CoreOS to the `sda` disk:

```nohighlight
$ kernel=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200118.3.0/x86_64/fedora-coreos-31.20200118.3.0-live-kernel-x86_64
$ initrd=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200118.3.0/x86_64/fedora-coreos-31.20200118.3.0-live-initramfs.x86_64.img
$ kernel_args='ip=dhcp rd.neednet=1 console=tty0 console=ttyS0 coreos.inst.install_dev=/dev/sda coreos.inst.stream=stable coreos.inst.ignition_url=https://dustymabe.com/2020-01-30/auto-login-serial-console-ttyS0.ign'
$
$ virt-install --name fcos --ram 2048 --vcpus 2 --disk size=20 \
               --network bridge=virbr0 --graphics=none \
               --install kernel=${kernel},initrd=${initrd},kernel_args_overwrite=yes,kernel_args="${kernel_args}"
```

This will launch an instance into a serial console and you'll see the
install scroll by:

```nohighlight
         Starting CoreOS Installer...
######################################################################## 100.0%
[   96.329276] coreos-installer-service[924]: coreos-installer install /dev/sda --ignition /tmp/coreos-installer-lPMZhg --firstboot-args rd.neednet=1 ip=dhcp  --stream stable
[   96.347656] coreos-installer-service[924]: Downloading stable image and signature
[  232.446299] coreos-installer-service[924]: gpg:                using RSA key 50CB390B3C3359C4
[  232.447695] coreos-installer-service[924]: gpg: Good signature from "Fedora (31) <fedora-31-primary@fedoraproject.org>" [ultimate]
[  233.824029] coreos-installer-service[924]: > Read disk 434.5 MiB/434.5 MiB (100%)
[  234.220963] coreos-installer-service[924]: Writing Ignition config
[  234.225558] coreos-installer-service[924]: Writing first-boot kernel arguments
[  234.264902] coreos-installer-service[924]: Install complete.
```

The installer then reboots the machine and the normal bootup
will occur. After ignition is run, the real root is mounted and
systemd brings the system up. Then the autologin happens on the
serial console (because in this case we used 
[auto-login-serial-console-ttyS0.ign](/2020-01-30/auto-login-serial-console-ttyS0.ign)).


```nohighlight
[  OK  ] Started RPM-OSTree System Management Daemon.

Fedora CoreOS 31.20200118.3.0
Kernel 5.4.10-200.fc31.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:AEg8Jt6J/zHz4iMMn25HoNFWOB4QWfSt3JaH2+xOqP8 (ECDSA)
SSH host key: SHA256:pELv/IoO4kYEtBMn4fjTq5sWShKyYAYSYgCVQGj93IU (ED25519)
SSH host key: SHA256:lp/ButDIqqkq3vrxsPMKslwtTFfaPg7XQF2qlEbywrc (RSA)
eth0: 192.168.122.9 fe80::5054:ff:feef:969e
localhost login: core (automatic login)

[core@localhost ~]$
```

And that's a full test cycle! Hopefully this can be useful to anyone
out there testing OS installs often.

Dusty
