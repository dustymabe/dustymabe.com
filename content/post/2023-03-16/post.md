---
title: 'NetworkManager: Limiting Bond Subordinate devices by MAC Address'
author: dustymabe
date: 2023-03-16
tags: [ coreos fedora networkmanager ]
draft: false
---

Someone recently asked me about locking down a bond to specific NIC
devices within the machine. Specifically they were concerned with
the sometimes unpredictable nature of NIC naming in Linux.

While there has been a lot of effort to make NIC naming more
predictable, it turns out with the networking configuration stack we
are using in Fedora/RHEL ([NetworkManager](https://networkmanager.dev/))
you don't even really need to care about the NIC device names if you
know the MAC Addresses of the interfaces you want to use.


## Defining Bond Nics via MAC Adresses Using NM Keyfiles

If we want to define a bond named `bond0` with two subordinate
interfaces that have the `52:54:00:20:65:3f` and `52:54:00:3a:45:8f`
MAC Addresses then we would write out three connection profiles for NetworkManager
to achieve this goal:

```
$ cat /etc/NetworkManager/system-connections/bond0.nmconnection
[connection]
id=bond0
type=bond
interface-name=bond0
[bond]
miimon=100
mode=active-backup
[ipv4]
dns-search=
may-fail=false
method=auto

$ cat /etc/NetworkManager/system-connections/bond0-sub0.nmconnection
[connection]
id=bond0-sub0
type=ethernet
master=bond0
slave-type=bond
[ethernet]
mac-address=52:54:00:20:65:3f

$ cat /etc/NetworkManager/system-connections/bond0-sub1.nmconnection
[connection]
id=bond0-sub1
type=ethernet
master=bond0
slave-type=bond
[ethernet]
mac-address=52:54:00:3a:45:8f
```

Once those are written out then a `nmcli c reload` and `nmcli c up bond0` should work.


## Deploying via NM keyfiles on Fedora CoreOS

For Fedora CoreOS, there are a
[few different ways you can configure networking](https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/).

To deploy the configuration described in the previous section [via Ignition](https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/#_via_ignition)
you can use a Butane yaml file like the one below to then [generate an Ignition config](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/#_configuration_process)
and feed that to your machine.

```yaml
variant: fcos
version: 1.4.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa AAAA...
storage:
  files:
    - path: /etc/NetworkManager/system-connections/bond0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0
          type=bond
          interface-name=bond0
          [bond]
          miimon=100
          mode=active-backup
          [ipv4]
          dns-search=
          may-fail=false
          method=auto
    - path: /etc/NetworkManager/system-connections/bond0-sub0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0-sub0
          type=ethernet
          master=bond0
          slave-type=bond
          [ethernet]
          mac-address=52:54:00:20:65:3f
    - path: /etc/NetworkManager/system-connections/bond0-sub1.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=bond0-sub1
          type=ethernet
          master=bond0
          slave-type=bond
          [ethernet]
          mac-address=52:54:00:3a:45:8f
```

Taking this config and [booting a machine with it using `virt-install`](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-libvirt/):

```
butane --pretty --strict config.bu --output config.ign
virt-install --import --name=fcos --vcpus=2 --memory=2048 \
        --os-variant=fedora-coreos-stable --graphics=none \
        --network bridge=virbr0,mac=52:54:00:20:65:3f \
        --network bridge=virbr0,mac=52:54:00:3a:45:8f \
        --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/config.ign" \
        --disk="size=10,backing_store=${PWD}/fedora-coreos-37.20230218.3.0-qemu.x86_64.qcow2"
```

After the machine boots up on the serial console you'll see:


```
Fedora CoreOS 37.20230218.3.0
Kernel 6.1.11-200.fc37.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:TVpjN8CcWBGJA70zm4Mo5WCBcF70FIxWOJn3dmLrLqQ (ECDSA)
SSH host key: SHA256:10nWjwSGmA3Emj+qngLCdmp6ZmuGow3PZNx8N2xEdMA (ED25519)
SSH host key: SHA256:tmRVqMA8cSleZbPLNbG+v8i/Ykzkm3iHX/EtoU72kHo (RSA)
bond0: 192.168.122.100 fe80::1d1a:885b:72e2:5816
enp1s0:  
enp2s0:  
Ignition: ran on 2023/03/16 19:36:18 UTC (this boot)
Ignition: user-provided config was applied
Ignition: wrote ssh authorized keys file for user: core
localhost login:
```

After SSHing into the machine you'll see the bond up and running:

```
$ ssh core@192.168.122.100
Warning: Permanently added '192.168.122.100' (ED25519) to the list of known hosts.
Fedora CoreOS 37.20230218.3.0
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/tag/coreos

[core@localhost ~]$ nmcli c show
NAME        UUID                                  TYPE      DEVICE
bond0       75ac1a13-dbce-36e4-8ecb-c6ed6fce5322  bond      bond0
bond0-sub0  85d6c15f-a99a-3989-8e9a-af89e619d960  ethernet  enp1s0
bond0-sub1  c1a6c92e-9de4-3c83-9b0a-f941462dadcc  ethernet  enp2s0

[core@localhost ~]$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp1s0: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether 5a:f0:f7:c7:cf:da brd ff:ff:ff:ff:ff:ff permaddr 52:54:00:20:65:3f
3: enp2s0: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether 5a:f0:f7:c7:cf:da brd ff:ff:ff:ff:ff:ff permaddr 52:54:00:3a:45:8f
4: bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 5a:f0:f7:c7:cf:da brd ff:ff:ff:ff:ff:ff
```
