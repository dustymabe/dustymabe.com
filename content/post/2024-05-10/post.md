---
title: 'Configuring and using iSCSI'
author: dustymabe
date: 2024-05-10
tags: [ iscsi ]
published: true
---

Recently I looked into enabling and testing multipath on top of iSCSI
for Fedora and Red Hat CoreOS. As part of that process I had the
opportunity to learn about iSCSI, which I had never played with
before. I'd like to document for my future self how to go about
setting up an iSCSI server and how to then access the exported
devices from another system.

## Setting up an iSCSI server

First off there are a few good references that were useful when
setting this up. The 
[RHEL 9 documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_storage_devices/configuring-an-iscsi-target_managing-storage-devices)
for managing storage devices was one. The other was the
[`targetcli` man page](https://www.mankier.com/8/targetcli).

For my setup I used Fedora Linux since that's the easiest way I know to get
started. We start off by installing the `iscsiadm` and `targetcli` userspace
utilities and enabling the `target` daemon:

```
sudo dnf install -y targetcli iscsi-initiator-utils
sudo systemctl enable target
sudo reboot
```

After reboot you can now see it is up and running:

```
$ sudo targetcli ls                                   
o- / ...................................................................... [...]
  o- backstores ........................................................... [...]
  | o- block ............................................... [Storage Objects: 0]
  | o- fileio .............................................. [Storage Objects: 0]
  | o- pscsi ............................................... [Storage Objects: 0]
  | o- ramdisk ............................................. [Storage Objects: 0]
  o- iscsi ......................................................... [Targets: 0]
  o- loopback ...................................................... [Targets: 0]
  o- vhost ......................................................... [Targets: 0]
```


We can then expose a block device (here `/dev/vdb`) as a backstore, create an
iSCSI target, a LUN, and set some attributes that allow access without requiring
authentication (this is for testing purposes, otherwise requiring auth would be a
good idea):

```
sudo targetcli backstores/block create name=coreos dev=/dev/vdb
sudo targetcli iscsi/ create iqn.2024-05.com.coreos
sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/luns create /backstores/block/coreos                                                               
sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/ set attribute \
    authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
```

If a full block device isn't available or desirable you could expose a file
backed disk image instead. A full example for that would look something like:

```
sudo targetcli backstores/fileio create coreos /var/coreos.img 10G
sudo targetcli iscsi/ create iqn.2024-05.com.coreos
sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/luns create /backstores/fileio/coreos                                                               
sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/ set attribute \
    authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
```


The output looks like:

```
$ sudo targetcli backstores/block create name=coreos dev=/dev/vdb
Created block storage object coreos using /dev/vdb.
$ sudo targetcli iscsi/ create iqn.2024-05.com.coreos
Created target iqn.2024-05.com.coreos.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.
$ sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/luns create /backstores/block/coreos
Created LUN 0.
$ sudo targetcli iscsi/iqn.2024-05.com.coreos/tpg1/ set attribute \
    authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
Parameter authentication is now '0'.
Parameter demo_mode_write_protect is now '0'.
Parameter generate_node_acls is now '1'.
Parameter cache_dynamic_acls is now '1'.
```

The configuration then looks like:

```
$ sudo targetcli ls                                   
o- / ...................................................................... [...]
  o- backstores ........................................................... [...]
  | o- block ............................................... [Storage Objects: 1]
  | | o- coreos ....................... [/dev/vdb (20.0GiB) write-thru activated]
  | |   o- alua ................................................ [ALUA Groups: 1]
  | |     o- default_tg_pt_gp .................... [ALUA state: Active/optimized]
  | o- fileio .............................................. [Storage Objects: 0]
  | o- pscsi ............................................... [Storage Objects: 0]
  | o- ramdisk ............................................. [Storage Objects: 0]
  o- iscsi ......................................................... [Targets: 1]
  | o- iqn.2024-05.com.coreos ......................................... [TPGs: 1]
  |   o- tpg1 ............................................... [gen-acls, no-auth]
  |     o- acls ....................................................... [ACLs: 0]
  |     o- luns ....................................................... [LUNs: 1]
  |     | o- lun0 .................. [block/coreos (/dev/vdb) (default_tg_pt_gp)]
  |     o- portals ................................................. [Portals: 1]
  |       o- 0.0.0.0:3260 .................................................. [OK]
  o- loopback ...................................................... [Targets: 0]
  o- vhost ......................................................... [Targets: 0]

```

We can now see if the iSCSI targets can be seen by running `iscsiadm`
from the same host:

```
$ sudo iscsiadm --mode discovery --type sendtargets --portal 127.0.0.1                                   │
127.0.0.1:3260,1 iqn.2024-05.com.coreos
```

If you want to poke a hole in the firewall to allow outside access
(assuming you have `firewalld` installed):

```
$ sudo firewall-cmd --add-port 3260/tcp --permanent
success
$ sudo firewall-cmd --add-port 3260/tcp
success
```

## Logging in from another system

On a different machine on the same network I can now try to access the
exported iSCSI devices:

```
core@localhost:~$ sudo iscsiadm -m discovery --type sendtargets --portal 192.168.122.194 --login
192.168.122.194:3260,1 iqn.2024-05.com.coreos
Logging in to [iface: default, target: iqn.2024-05.com.coreos, portal: 192.168.122.194,3260]
Login to [iface: default, target: iqn.2024-05.com.coreos, portal: 192.168.122.194,3260] successful.

core@localhost:~$ ls -l /dev/disk/by-path/ip-192.168.122.194\:3260-iscsi-iqn.2024-05.com.coreos-lun-0
lrwxrwxrwx. 1 root root 9 May 10 20:57 /dev/disk/by-path/ip-192.168.122.194:3260-iscsi-iqn.2024-05.com.coreos-lun-0 -> ../../sdb
```

So that tells us `/dev/sdb` is the mapped iSCSI device. We can now
write to the disk. In this case let's install Fedora CoreOS to the
disk and give it kernel command line options that tell it that the
root device will be on iSCSI and to pick up iSCSI information from
the iBFT firmware:

```
$ sudo coreos-installer install --append-karg rd.iscsi.firmware=1 --console ttyS0,115200n8 -i config.ign /dev/sdb
Downloading Fedora CoreOS stable x86_64 metal image (raw.xz) and signature
> Read disk 670.3 MiB/670.3 MiB (100%)   
gpg: Signature made Tue May  7 05:11:08 2024 UTC
gpg:                using RSA key 115DF9AEF857853EE8445D0A0727707EA15B79CC
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   4  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 4u
gpg: Good signature from "Fedora (40) <fedora-40-primary@fedoraproject.org>" [ultimate]
Writing Ignition config
Modifying kernel arguments

Install complete.
```

Now we can drop the iSCSI association to relinquish the device.

```
core@localhost:~$ sudo iscsiadm --mode node --logoutall=all
Logging out of session [sid: 34, target: iqn.2024-05.com.coreos, portal: 192.168.122.194,3260]
Logout of [sid: 34, target: iqn.2024-05.com.coreos, portal: 192.168.122.194,3260] successful.
```

## Booting directly from a remote iSCSI disk 


We can now directly boot (via iSCSI) a machine from the disk we wrote Fedora
CoreOS onto. We can do this via an iPXE config with a `sanboot` directive. The
iPXE config looks something like:

```
#!ipxe                                                    
# set some random uuid as the initiator iqn. we can use   
# a random value here because we don't have ACL's enabled,
# but we do need to provide it because otherwise this will
# fail pointing to https://ipxe.org/1c0d6502              
set initiator-iqn iqn.68cc69b9-1b54-4ff1-9d61-eedb570da8fd
sanboot iscsi:192.168.122.194::::iqn.2024-05.com.coreos
```

[PXE booting a VM with this iPXE config](/2019/09/13/update-on-easy-pxe-boot-testing-post-minus-pxelinux/)
we can watch it boot:

```
virt-install --name pxe --pxe --network bridge=virbr0        \
    --memory 2048 --disk none --osinfo detect=on,require=off \
    --boot menu=on,useserial=on --boot network --autoconsole text
```

and then log in via SSH to see the root device is actually backed by iSCSI:

```
$ ssh core@192.168.122.250
Warning: Permanently added '192.168.122.250' (ED25519) to the list of known hosts.
Fedora CoreOS 40.20240416.3.1
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/tag/coreos

core@localhost:~$ 
core@localhost:~$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk 
├─sda1   8:1    0    1M  0 part 
├─sda2   8:2    0  127M  0 part 
├─sda3   8:3    0  384M  0 part /boot
└─sda4   8:4    0 19.5G  0 part /var
                                /sysroot/ostree/deploy/fedora-coreos/var
                                /usr
                                /etc
                                /
                                /sysroot
core@localhost:~$ 
core@localhost:~$ ls -l /dev/disk/by-path/ip-192.168.122.194\:3260-iscsi-iqn.2024-05.com.coreos-lun-0
lrwxrwxrwx. 1 root root 9 May 10 21:33 /dev/disk/by-path/ip-192.168.122.194:3260-iscsi-iqn.2024-05.com.coreos-lun-0 -> ../../sda
```

And that's all! The `--boot network` will cause the VM to continue to
boot from the network and each time it will boot from iSCSI via the
`sanboot` iPXE directive.
