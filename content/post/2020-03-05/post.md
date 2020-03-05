---
title: 'Network teaming using NetworkManager keyfiles on Fedora CoreOS'
author: dustymabe
date: 2020-03-05
tags: [ fedora, coreos, NetworkManager ]
published: true
---

# Introduction

[NetworkManager](https://gitlab.freedesktop.org/NetworkManager/NetworkManager)
allows connections to be defined in a configuration file known as a
[keyfile](https://developer.gnome.org/NetworkManager/stable/nm-settings-keyfile.html)
, which is a simple .ini-style formatted file with different
key=value pairs. In 
[Fedora CoreOS](https://getfedora.org/coreos/)
we've elected to use NetworkManager with keyfiles as the way to
configure networking. In case you have a standard networking
environment with NICs requesting DHCP then you probably won't need to
configure networking. However, if you'd like to have a static
networking config or if you'd like to do something more complicated
(like configure
[network teaming](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/configuring-network-teaming_configuring-and-managing-networking)
for a few interfaces) then you'll need to create a keyfile
that NetworkManager will then use to configure the interfaces
on the machine.

Let's try it out!

# Teaming two NICs

In this example we'll create some NM keyfiles from scratch, though
an alternative way to generate a few keyfiles is to use `nmcli` on
an already booted systemd and glean some of the contents.

In this example I'll define an 
[fcct config](https://github.com/coreos/fcct/)
that will create the following files:

- `/etc/NetworkManager/system-connections/team0.nmconnection`
- `/etc/NetworkManager/system-connections/team0-slave-eth0.nmconnection`
- `/etc/NetworkManager/system-connections/team0-slave-eth1.nmconnection`


Here is the fcct config:

```nohighlight
$ cat ./fcct-teaming.yaml
variant: fcos
version: 1.0.0
systemd:
  units:
    - name: serial-getty@ttyS0.service
      dropins:
      - name: autologin-core.conf
        contents: |
          [Service]
          # Override Execstart in main unit
          ExecStart=
          # Add new Execstart with `-` prefix to ignore failure
          ExecStart=-/usr/sbin/agetty --autologin core --noclear %I $TERM
          TTYVTDisallocate=no
storage:
  files:
    - path: /etc/NetworkManager/system-connections/team0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0
          type=team
          interface-name=team0
          [team]
          config={"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}
    - path: /etc/NetworkManager/system-connections/team0-slave-eth0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-eth0
          type=ethernet
          interface-name=eth0
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}
    - path: /etc/NetworkManager/system-connections/team0-slave-eth1.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-eth1
          type=ethernet
          interface-name=eth1
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}
```

You'll notice that the keyfiles that we create have `0600` permissions
because NetworkManager won't read them without strict permissions. You'll
also notice that in the keyfiles we set different settings. Some are
[connection settings](https://developer.gnome.org/NetworkManager/stable/settings-connection.html)
some are
[team settings](https://developer.gnome.org/NetworkManager/stable/settings-team.html)
and some are
[team-port settings](https://developer.gnome.org/NetworkManager/stable/settings-team-port.html).
For your use case you might want to tweak these settings or add some
other settings that are documented in the linked documentation.

For reference, the keyfiles we are creating are roughly equivalent
to running the following sequence of `nmcli` commands on a traditional
Fedora system:

```nohighlight
$ sudo nmcli connection add type team con-name team0 ifname team0
$ sudo nmcli connection modify team0 team.config '{"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}'
$ sudo nmcli connection add type team-slave con-name team0-slave-eth0 ifname eth0 master team0
$ sudo nmcli connection modify team0-slave-eth0 team-port.config '{"prio": 100}'
$ sudo nmcli connection add type team-slave con-name team0-slave-eth1 ifname eth1 master team0
$ sudo nmcli connection modify team0-slave-eth1 team-port.config '{"prio": 100}'
```

Now that we have the config defined we can run `fcct` to get
the Ignition config we'll pass to the system on boot:

```nohighlight
$ fcct --input ./fcct-teaming.yaml --pretty --output teaming.ign
```

**NOTE:** There is a current issue where you must reboot once in
          order to have teaming be properly brought up. This shouldn't
          be an issue once we have
          [Networkmanager in the initrd](https://github.com/coreos/fedora-coreos-tracker/issues/394).

After booting the machine I can see that the teaming interface is
brought up properly by NetworkManager:

```nohighlight
[core@localhost ~]$ nmcli connection show
NAME              UUID                                  TYPE      DEVICE
team0             0aa06eb5-2de6-3daa-aed2-a24320f377c6  team      team0
team0-slave-eth0  be410907-da86-3be3-9d53-569852330371  ethernet  eth0
team0-slave-eth1  44bdde01-d5ba-3cba-8e19-5fa4cde0b6c2  ethernet  eth1
[core@localhost ~]$
[core@localhost ~]$ ip -4 -o a
1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
4: team0    inet 192.168.122.94/24 brd 192.168.122.255 scope global dynamic noprefixroute team0\       valid_lft 3080sec preferred_lft 3080sec
[core@localhost ~]$
[core@localhost ~]$ sudo teamdctl team0 state
setup:
  runner: activebackup
ports:
  eth0
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
  eth1
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
runner:
  active port: eth0
```

# Teaming two NICs with static networking

We can bring up teaming for two NICs with a static networking config
by adding some information into the
[ipv4](https://developer.gnome.org/NetworkManager/stable/settings-ipv4.html)
or
[ipv6](https://developer.gnome.org/NetworkManager/stable/settings-ipv6.html)
sections of the `team0.nmconnection` config file.

In this example we'll set the following settings:

```nohighlight
ipv4.method=manual
ipv4.addresses=192.168.122.2/24
ipv4.gateway=192.168.122.1
ipv4.dns=8.8.8.8
ipv4.dns-search=redhat.com
```

Here is the `fcct` config:

```nohighlight
$ cat fcct-teaming-static-ipv4.yaml
variant: fcos
version: 1.0.0
systemd:
  units:
    - name: serial-getty@ttyS0.service
      dropins:
      - name: autologin-core.conf
        contents: |
          [Service]
          # Override Execstart in main unit
          ExecStart=
          # Add new Execstart with `-` prefix to ignore failure
          ExecStart=-/usr/sbin/agetty --autologin core --noclear %I $TERM
          TTYVTDisallocate=no
storage:
  files:
    - path: /etc/NetworkManager/system-connections/team0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0
          type=team
          interface-name=team0
          [team]
          config={"runner": {"name": "activebackup"}, "link_watch": {"name": "ethtool"}}
          [ipv4]
          method=manual
          addresses=192.168.122.2/24
          gateway=192.168.122.1
          dns=8.8.8.8
          dns-search=redhat.com
    - path: /etc/NetworkManager/system-connections/team0-slave-eth0.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-eth0
          type=ethernet
          interface-name=eth0
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}
    - path: /etc/NetworkManager/system-connections/team0-slave-eth1.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=team0-slave-eth1
          type=ethernet
          interface-name=eth1
          master=team0
          slave-type=team
          [team-port]
          config={"prio": 100}
```

Once converted an Ignition config and used to bring up a systemd
we can see it's applied appropriately:

```nohighlight
[core@localhost ~]$ nmcli connection show
NAME              UUID                                  TYPE      DEVICE
team0             0aa06eb5-2de6-3daa-aed2-a24320f377c6  team      team0
team0-slave-eth0  be410907-da86-3be3-9d53-569852330371  ethernet  eth0
team0-slave-eth1  44bdde01-d5ba-3cba-8e19-5fa4cde0b6c2  ethernet  eth1
[core@localhost ~]$
[core@localhost ~]$ ip -4 -o a
1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
4: team0    inet 192.168.122.2/24 brd 192.168.122.255 scope global noprefixroute team0\       valid_lft forever preferred_lft forever
[core@localhost ~]$
[core@localhost ~]$ cat /etc/resolv.conf
# Generated by NetworkManager
search redhat.com
nameserver 8.8.8.8
```

# Conclusion

I hope this helps show how to set up teaming using NetworkManager
keyfiles, which is how we're configuring networking on Fedora CoreOS.

Cheers!
