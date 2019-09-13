---
title: 'Easy PXE boot testing with only HTTP using iPXE and libvirt'
author: dustymabe
date: 2019-01-04
tags: [ fedora, libvirt, PXE ]
published: true
---

**Update**: A future
            [post](/2019/09/13/update-on-easy-pxe-boot-testing-post-minus-pxelinux/)
            explains how to do this even easier without PXELINUX.

# Introduction

Occasionally I have a need to test out a PXE install workflow. All of
this is super easy if you have a permanent PXE infrastructure you maintain
which traditionally has consisted of DHCP, TFTP and HTTP/FTP servers.
What if I just have my laptop and want to test something in a VM? It turns
out it's pretty easy to do using libvirt and a simple http server.

In the steps below I walk through setting up libvirt to point to a web server
for PXE booting that has been set up with all the files needed for testing out
a PXE install workflow.

# Background

Libvirt uses [iPXE](https://ipxe.org/) as the firmware for network booting 
in the network interfaces for VMs. This firmware has the ability to retrieve
the pxelinux boot file, kernel, and initrd [over HTTP](http://etherboot.org/wiki/httpboot#http_booting),
which means that we aren't required to set up a TFTP server any longer.

# Web Server Setup

**NOTE:** I'm executing all of these steps on a Fedora 29 host.

The first thing we can do is make a new directory and switch to it.


```nohighlight
$ mkdir pxeserver && cd pxeserver
```

Next we'll grab `pxelinux.0` and `ldlinux.c32` files from the `syslinux` packages within Fedora:


**NOTE:** You can execute this step in a container if you do not want to install packages on the host.


```nohighlight
$ dnf install -y syslinux-nonlinux
...
$ cp /usr/share/syslinux/{pxelinux.0,ldlinux.c32} ./
```

Next I'll use the 
[install media for Fedora 29 server](https://download.fedoraproject.org/pub/fedora/linux/releases/29/Server/x86_64/iso/Fedora-Server-dvd-x86_64-29-1.2.iso)
to create an install tree which can be served by our web server. In the
commands below I'm just loopmounting the ISO image on top of the
`Fedora-Server-dvd-x86_64-29-1.2.iso` directory. I could have also just
used `rsync` to copy the files out of the ISO too. Either way works.


```nohighlight
$ mkdir Fedora-Server-dvd-x86_64-29-1.2.iso
$ sudo mount -o loop /var/b/images/Fedora-Server-dvd-x86_64-29-1.2.iso ./Fedora-Server-dvd-x86_64-29-1.2.iso/
mount: /var/b/shared/pxeserver/Fedora-Server-dvd-x86_64-29-1.2.iso: WARNING: device write-protected, mounted read-only.
$
$ ls Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/
initrd.img  TRANS.TBL  vmlinuz
```

You can see from that last `ls` that the kernel and initrd for pxe booting
are under `Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/`. We'll now
create a default pxelinux configuration file and specify the location of the
kernel and initrd.

```nohighlight
$ mkdir pxelinux.cfg
$ cat <<EOF > pxelinux.cfg/default
DEFAULT pxeboot
TIMEOUT 20
PROMPT 0
LABEL pxeboot
    KERNEL Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/vmlinuz
    APPEND initrd=Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/initrd.img console=ttyS0 inst.ks=http://192.168.122.1:8000/kickstart.cfg
IPAPPEND 2
EOF
```

In the configuration file we do specify `console=ttyS0` so we can view
output from the install on the serial console. We also specify the 
location of a kickstart file which I'll create now:


```nohighlight
$ cat <<EOF > kickstart.cfg
url --url http://192.168.122.1:8000/Fedora-Server-dvd-x86_64-29-1.2.iso/
reboot
rootpw --plaintext foobar
services --enabled="sshd,chronyd"
zerombr
clearpart --all
autopart --type lvm
%packages
@core
%end
EOF
```

This is just an example kickstart file and is as simple as possible.


Now our directory structure looks like this:

```nohighlight
$ tree -L 2
.
├── Fedora-Server-dvd-x86_64-29-1.2.iso
│   ├── EFI
│   ├── Fedora-Legal-README.txt
│   ├── images
│   ├── isolinux
│   ├── LICENSE
│   ├── media.repo
│   ├── Packages
│   ├── repodata
│   └── TRANS.TBL
├── kickstart.cfg
├── ldlinux.c32
├── pxelinux.0
└── pxelinux.cfg
    └── default
```

We'll go ahead and start the web server in this terminal:

**NOTE**: You may need to poke a hole in your firewall for port
          `8000`. You can use a command like `sudo firewall-cmd --add-port 8000/tcp`.

```nohighlight
$ python3 -m http.server 
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```

# Libvirt network DHCP setup

In another terminal we'll edit the network configuration for the
default libvirt network to tell it to serve out a boot dhcp option
that tells clients where a network boot file is that can be used
to network boot the mahcine. We do this by adding a
`<bootp file='http://192.168.122.1:8000/pxelinux.0'/>` line to
the `<dhcp>` XML element.

**NOTE**: Please bring down all VMs on your default libvirt network
        before executing this next step.

The steps for bringing down, editing, and re-starting the libvirt
network look like:

```nohighlight
$ virsh net-destroy default
$ virsh net-edit default
$ virsh net-start default
```

When all is done my final XML looked like:

```nohighlight
<network>
  <name>default</name>
  <uuid>356e5daf-3b06-49d5-98fd-178e847cf559</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:aa:da:73'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <bootp file='http://192.168.122.1:8000/pxelinux.0'/>
    </dhcp>
  </ip>
</network>
```

# PXE Booting!

Finally I should be able to start a virtual machine and have it
grab the PXE configuration I have defined and is being served from
the python web server. The command I use to start a VM for this
looks like:

```nohighlight
$ virt-install --pxe --network network=default --name pxe --memory 2048 --disk size=10 --nographics --boot menu=on,useserial=on
```

In the serial console I can see fact that the `pxelinux.0` file
and the `vmlinuz` and `initrd.img` were retrieved:

```nohighlight
SeaBIOS (version ?-20180724_192412-buildhw-07.phx2.fedoraproject.org-1.fc29)
Machine UUID af153013-d6ef-421b-b0f1-1bbfd88cd7e9


iPXE (http://ipxe.org) 00:02.0 C100 PCI2.10 PnP PMM+7FF91200+7FED1200 C100
                                                                               

Booting from ROM...
iPXE (PCI 00:02.0) starting execution...ok
iPXE initialising devices...ok


iPXE 1.0.0+ -- Open Source Network Boot Firmware -- http://ipxe.org
Features: DNS HTTP iSCSI TFTP AoE ELF MBOOT PXE bzImage Menu PXEXT

net0: 52:54:00:59:73:4c using rtl8139 on 0000:00:02.0 (open)
  [Link:up, TX:0 TXE:0 RX:0 RXE:0]
Configuring (net0 52:54:00:59:73:4c).................. ok
net0: 192.168.122.65/255.255.255.0 gw 192.168.122.1
net0: fe80::5054:ff:fe59:734c/64
Next server: 192.168.122.1
Filename: http://192.168.122.1:8000/pxelinux.0
http://192.168.122.1:8000/pxelinux.0... ok
pxelinux.0 : 42780 bytes [PXE-NBP]

PXELINUX 6.04 PXE  Copyright (C) 1994-2015 H. Peter Anvin et al
Loading Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/vmlinuz... ok
Loading Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/initrd.img...ok
Probing EDD (edd=off to disable)... ok
```

The machine continues on booting and completes the kickstart!

# Conclusion

So we were able to PXE boot without TFTP and by re-using the DHCP server
that is already built into libvirt. Even though we took shortcuts this should
work with any network card that supports iPXE if you can configure the DHCP
server in the network to serve out the filename to the nodes.

Happy New Year All!
