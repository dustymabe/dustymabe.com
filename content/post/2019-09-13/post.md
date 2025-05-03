---
title: 'Update on Easy PXE boot testing post: minus PXELINUX'
author: dustymabe
date: 2019-09-13
tags: [ fedora, libvirt, PXE ]
draft: false
---

# Introduction

This is an update to my 
[previous post](/2019/01/04/easy-pxe-boot-testing-with-only-http-using-ipxe-and-libvirt/)
about easily testing PXE booting by using libvirt + iPXE.

Several people have notified me (thanks Lukas Zapletal and others) that instead
of leveraging
[PXELINUX](https://wiki.syslinux.org/wiki/index.php?title=PXELINUX)
that I could just use an iPXE script to do the same thing. I hadn't
used iPXE much so here's an update on how to achieve the same goal
using an iPXE script instead of a PXELINUX binary+config.

# Using an iPXE script

From my 
[previous post](/2019/01/04/easy-pxe-boot-testing-with-only-http-using-ipxe-and-libvirt/)
you would do all of the same steps except in the **Web Server Setup**
section you don't need to install the `syslinux-nonlinux` package to
grab the binaries out and you also don't need to make a `pxelinux.cfg` file/directory
structure.

Instead you create a an iPXE script (let's call it `boot.ipxe`) with
contents like so:

```nohighlight
$ cat boot.ipxe 
#!ipxe
kernel Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/vmlinuz console=ttyS0 inst.ks=http://192.168.122.1:8000/kickstart.cfg
initrd Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/initrd.img
boot
```

In the **Libvirt network DHCP setup** of the
[previous post](/2019/01/04/easy-pxe-boot-testing-with-only-http-using-ipxe-and-libvirt/)
you would then make your `bootp file` point at the iPXE script
(`boot.ipxe`) instead of the `pxelinux.0` binary like is instructed
in that previous post.

My final XML looks like:

```nohighlight
<network>
  <name>default</name>
  <uuid>d8be1970-37ca-44f2-965a-7e63305e6850</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:93:a5:73'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <bootp file='http://192.168.122.1:8000/boot.ipxe'/>
    </dhcp>
  </ip>
</network>
```

Everything else from the previous post should be the the same!

# PXE Booting

You can boot like so:

```nohighlight
$ virt-install --pxe --network network=default --name pxe --memory 2048 --disk size=10 --nographics --boot menu=on,useserial=on
```

And in the serial console you see the fact that `boot.ipxe` was
used this time instead of `pxelinux.0`.

```nohighlight
SeaBIOS (version ?-20180724_192412-buildhw-07.phx2.fedoraproject.org-1.fc29)
Machine UUID 9358886f-f5c0-4839-9ce4-8d7c59c5f9ab


iPXE (http://ipxe.org) 00:02.0 C100 PCI2.10 PnP PMM+7FF91130+7FED1130 C100



Press ESC for boot menu.

Booting from ROM...
iPXE (PCI 00:02.0) starting execution...ok
iPXE initialising devices...ok



iPXE 1.0.0+ -- Open Source Network Boot Firmware -- http://ipxe.org
Features: DNS HTTP iSCSI TFTP AoE ELF MBOOT PXE bzImage Menu PXEXT

net0: 52:54:00:2f:bb:8a using 82540em on 0000:00:02.0 (open)
  [Link:up, TX:0 TXE:0 RX:0 RXE:0]
Configuring (net0 52:54:00:2f:bb:8a).................. ok
net0: 192.168.122.216/255.255.255.0 gw 192.168.122.1
net0: fe80::5054:ff:fe2f:bb8a/64
Next server: 192.168.122.1
Filename: http://192.168.122.1:8000/boot.ipxe
http://192.168.122.1:8000/boot.ipxe... ok
boot.ipxe : 209 bytes [script]
Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/vmlinuz... ok
Fedora-Server-dvd-x86_64-29-1.2.iso/images/pxeboot/initrd.img... ok
Probing EDD (edd=off to disable)... ok
```

# Conclusion

PXE booting has become even easier! Who knew :)
