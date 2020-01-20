---
title: 'Devconf.cz 2020 Fedora CoreOS Lab' 
author: dustymabe
date: 2020-01-20
tags: [ fedora, coreos, ignition ]
published: true
---

Fedora CoreOS is blah blah blah auto updates blah containers blah.



Fedora CoreOS is delivered as a disk image. In every environment where
Fedora CoreOS is started the initial boot starts with roughly the same
disk image. In cloud environments these are cloud images that were
made specifically for that cloud. For bare metal environments the
[coreos-installer]() can be used, which performs a glorified bit for bit
copy of the disk image with some convenience factors added.

If the delivered artifact is a disk image how do I customize a Fedora CoreOS 
to do what I need it to do? Create an Ignition config!

# What is Ignition?

Fedora CoreOS uses 
[Ignition]()
to provision a node in an automated fashion. Ignition config files are
written in JSON and typically not user friendly. For that reason
Fedora CoreOS offers the
[Fedora CoreOS Config Transpiler]()
(also known as FCCT)
that will create igntion configs from a more user friendly format and
also the
[ignition-validate]()
sub-utility that can be used to verify Ignition config files before
attempting to launch a machine.

# First Ignition config (created with FCCT):

Let's create a very simple config that will add a systemd dropin to override
the normal `serial-getty@ttyS0.service`. This unit will automatically log the
`core` user in to the serial console of the booted machine:

```
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
```

We'll then use `fcct` to convert that into an ignition config:

```
$ fcct -pretty -strict -input ./fcct-auto-login-ttyS0.yaml -output auto-login-ttyS0.ign
$ cat auto-login-ttyS0.ign
{
  "ignition": {
    "config": {
      "replace": {
        "source": null,
        "verification": {}
      }
    },
    "security": {
      "tls": {}
    },
    "timeouts": {},
    "version": "3.0.0"
  },
  "passwd": {},
  "storage": {},
  "systemd": {
    "units": [
      {
        "dropins": [
          {
            "contents": "[Service]\n# Override Execstart in main unit\nExecStart=\n# Add new Execstart with `-` prefix to ignore failure\nExecStart=-/usr/sbin/agetty --autologin core --noclear %I $TERM\nTTYVTDisallocate=no\n",
            "name": "autologin-core.conf"
          }
        ],
        "name": "serial-getty@ttyS0.service"
      }
    ]
  }
}
```

Luckily `fcct` outputs valid Ignition configs. However, if you are tweaking the
config after `fcct` or otherwise providing hand edited Ignition configs you'll want
to always use `ignition-validate` to perform some verification on the config. We'll
do that now to illustrate how:

```
$ ignition-validate --version
Ignition 2.1.1
$ ignition-validate ./auto-login-ttyS0.ign && echo 'success!'
success!
```

# Boot a Fedora CoreOS instance for the first time

Given that we've now created an ignition config. Let's try to boot a
VM with an image and that config. For this lab we'll use the `qemu` image
but you should be able to use that ignition config with any of the
artifacts that are published for a Fedora CoreOS release.

In this case we'll use libvirt/qemu/kvm to boot directly into Fedora
CoreOS from the qemu image.

```
cp /var/b/shared/code/github.com/dustymabe/dustymabe.com/content/post/2020-01-21/auto-login-ttyS0.ign /run/user/1001/
virt-install --name=fcos --vcpus=2 --ram=2048 --import \
    --network=bridge=virbr0 --graphics=none            \
    --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/run/user/1001/auto-login-ttyS0.ign" \
    --disk=size=20,backing_store=/var/b/images/fedora-coreos-31.20200113.3.1-qemu.x86_64.qcow2
```

This command will start an instance named `fcos` from the 
`fedora-coreos-31.20200113.3.1-qemu.x86_64.qcow2` image using the
`auto-login-ttyS0.ign` Ignition config. It will auto-attach to the
serial console of the machine so you'll be able to see the image
bootup messages. Also of note is that it uses the `backing_store`
option to `--disk` so it won't write to the downloaded image, but
rather a new disk image that can easily be thrown away.

Once the machine is booted up you should see a few prompts and then
you should be automatically logged in and presented with a bash shell:

```
[  OK  ] Started RPM-OSTree System Management Daemon.

Fedora CoreOS 31.20200113.3.1
Kernel 5.4.8-200.fc31.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:i+04yU6UFy6VksNU6Nno64j0zawGfa5TFqZMp5bAGbQ (ECDSA)
SSH host key: SHA256:Muri2ChT4NTMiVpHnM0eZB/THMx8HkdAvQpZ5UGec9s (ED25519)
SSH host key: SHA256:jd5rsPMtKScUiCB2WxcQCDCn44JjoluZPBsQJbbAlrA (RSA)
eth0: 192.168.122.76 fe80::5054:ff:fe29:657b
localhost login: core (automatic login)

[core@localhost ~]$
```

# Exploring Fedora CoreOS internals:

Once you have access to the console of the machine you can browse around a bit
to see some of the different pieces of the operating system. For one you can still
inspect the system to see what it was composed of by using `rpm`:

```
$ rpm -q ignition kernel moby-engine podman systemd rpm-ostree zincati
ignition-2.1.1-3.git40c0b57.fc31.x86_64
kernel-5.4.8-200.fc31.x86_64
moby-engine-18.09.8-2.ce.git0dd43dd.fc31.x86_64
podman-1.7.0-2.fc31.x86_64
systemd-243.5-1.fc31.x86_64
rpm-ostree-2019.7-1.fc31.x86_64
zincati-0.0.6-1.fc31.x86_64
```

You can also inspect the current revision of Fedora CoreOS:

```
[core@localhost ~]$ rpm-ostree status 
State: idle
AutomaticUpdates: disabled
Deployments:
* ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200113.3.1 (2020-01-14T00:20:15Z)
                    Commit: f480038412cba26ab010d2cd5a09ddec736204a6e9faa8370edaa943cf33c932
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4
```

And check on `zincati.service`, which communicates with our update server and
tells `rpm-ostree` when to do an update and to what version to update to:

```
[core@localhost ~]$ systemctl status zincati.service | cat
● zincati.service - Zincati Update Agent
   Loaded: loaded (/usr/lib/systemd/system/zincati.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2020-01-17 19:52:44 UTC; 19min ago
     Docs: https://github.com/coreos/zincati
 Main PID: 1060 (zincati)
    Tasks: 2 (limit: 2297)
   Memory: 14.1M
   CGroup: /system.slice/zincati.service
           └─1060 /usr/libexec/zincati agent -v

Jan 17 19:52:44 localhost systemd[1]: Started Zincati Update Agent.
Jan 17 19:52:44 localhost zincati[1060]: [INFO ] starting update agent (zincati 0.0.6)
Jan 17 19:52:46 localhost zincati[1060]: [INFO ] Cincinnati service: https://updates.coreos.stg.fedoraproject.org
Jan 17 19:52:46 localhost zincati[1060]: [INFO ] agent running on node '0a2e25d88a604d8c9873cd6079cd2a28', in update group 'default'
Jan 17 19:52:46 localhost zincati[1060]: [INFO ] initialization complete, auto-updates logic enabled
```

One other interesting thing to do is view the logs from Ignition in case
there is anything interesting there you may want to investigate:

```
[core@localhost ~]$ journalctl -t ignition | cat
```

And finally, of course you can use the `docker` (provided by `moby-engine` rpm)
or `podman` commands to inspect the current state of containers on the system:

```
$ podman version
$ podman info
$ sudo docker info
$ sudo docker version
```

```
*NOTE* : You need `sudo` for docker commands. `podman` commands can be run as 
          `root` or non-root.
*NOTE* : Running a `docker` command will cause the docker daemon to be started
          if it was not already started.
```

# Taking down the Virtual Machine

Let's now get rid of that VM so we can start again from scratch:

```
$ virsh destroy fcos
$ virsh undefine --remove-all-storage fcos
```

# A More Complicated Provisioning Scenario

So what is running a server all about? Hosting services, crunching data,
mining bitcoin? Ding ding ding. Let's do something with our Fedora CoreOS
node! 

Since Fedora CoreOS is focused on running applications/services in
containers we recommend trying to only run containers and not modifying the
host directly. This makes automatic updates more reliable and allows for
separation of concerns with the Fedora CoreOS team responsible for the OS and
end-user operators/sysadmins responsible for the applications.

In this case let's do a few more things in addition to the serial console
autologin in our FCCT config:

- Add an SSH key for the `core` user
- Add a systemd service (`failure.service`) that fails on boot
- Add a systemd service that will use a container to bring up a hosted service


We'll create this config in a file called `./fcct-more-complicated.yaml`

```
$ cat fcct-more-complicated.yaml
variant: fcos
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-rsa AAAA...
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
    - name: failure.service
      enabled: true
      contents: |
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/false
        RemainAfterExit=yes
        [Install]
        WantedBy=multi-user.target
    - name: etcd-member.service
      enabled: true
      contents: |
        [Unit]
        Description=Run single node etcd
        After=network-online.target
        Wants=network-online.target
        [Service]
        ExecStartPre=mkdir -p /var/lib/etcd
        ExecStartPre=-/bin/podman kill etcd
        ExecStartPre=-/bin/podman rm etcd
        ExecStartPre=-/bin/podman pull quay.io/coreos/etcd
        ExecStart=/bin/podman run --name etcd --net=host \
                    --volume /var/lib/etcd:/etcd-data:z  \
                    quay.io/coreos/etcd:latest /usr/local/bin/etcd              \
                            --data-dir /etcd-data --name node1                  \
                            --initial-advertise-peer-urls http://127.0.0.1:2380 \
                            --listen-peer-urls http://127.0.0.1:2380            \
                            --advertise-client-urls http://127.0.0.1:2379       \
                            --listen-client-urls http://127.0.0.1:2379          \
                            --initial-cluster node1=http://127.0.0.1:2380
        ExecStop=/bin/podman stop etcd
        [Install]
        WantedBy=multi-user.target
```

We can run `fcct` to convert that to an Ignition config:

```
$ fcct -pretty -strict -input ./fcct-more-complicated.yaml -output more-complicated.ign
$ ignition-validate ./more-complicated.ign && echo 'success!'
success!
```

```
cp /var/b/shared/code/github.com/dustymabe/dustymabe.com/content/post/2020-01-21/more-complicated.ign /run/user/1001/
virt-install --name=fcos --vcpus=2 --ram=2048 --import \
    --network=bridge=virbr0 --graphics=none            \
    --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=/run/user/1001/more-complicated.ign" \
    --disk=size=20,backing_store=/var/b/images/fedora-coreos-31.20200113.3.1-qemu.x86_64.qcow2
```


On the serial console you should see:
```
Fedora CoreOS 31.20200113.3.1                                                                                         
Kernel 5.4.8-200.fc31.x86_64 on an x86_64 (ttyS0)                                                                     
                                                                                                                      
SSH host key: SHA256:SHbuaQuQaO4yUxlIagkSSZflG5cEWqRe+hjDMdSZYag (ECDSA)                                                                                                                                                                     
SSH host key: SHA256:98KGTRjjeU5S2LBr9L9Yt+8fwrQjkERvsyWYF0TwUN8 (ED25519)
SSH host key: SHA256:DNzbdc7F5dxua63jjXPijUTzRhpXWvQ6IuRTsHKcKBc (RSA)
eth0: 192.168.122.254 fe80::5054:ff:fe35:aa82                                                                         
localhost login: core (automatic login)     
                                                                                                                      
Failed Units: 1                                                                                                                                                                                                                              
  failure.service
```

On SSH:
```
$ ssh core@192.168.122.254
The authenticity of host '192.168.122.254 (192.168.122.254)' can't be established.
ECDSA key fingerprint is SHA256:SHbuaQuQaO4yUxlIagkSSZflG5cEWqRe+hjDMdSZYag.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.122.254' (ECDSA) to the list of known hosts.
Fedora CoreOS 31.20200113.3.1
Tracker: https://github.com/coreos/fedora-coreos-tracker

Last login: Fri Jan 17 21:19:20 2020
[systemd]
Failed Units: 1
  failure.service
[core@localhost ~]$
```

The Failed Units is coming from the
[console login helper messages](https://github.com/rfairley/console-login-helper-messages)
helpers. This particular helper shows us when systemd has services
that are in a failed state.


Now that we are up let's check on the status of the `etcd-member`
service:

```
[core@localhost ~]$ systemctl status etcd-member.service
● etcd-member.service - Run single node etcd
   Loaded: loaded (/etc/systemd/system/etcd-member.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2020-01-17 21:19:20 UTC; 29s ago
  Process: 1128 ExecStartPre=/usr/bin/mkdir -p /var/lib/etcd (code=exited, status=0/SUCCESS)
  Process: 1143 ExecStartPre=/bin/podman kill etcd (code=exited, status=125)
  Process: 1354 ExecStartPre=/bin/podman rm etcd (code=exited, status=1/FAILURE)
  Process: 1426 ExecStartPre=/bin/podman pull quay.io/coreos/etcd (code=exited, status=0/SUCCESS)
 Main PID: 2185 (podman)
    Tasks: 10 (limit: 2297)
   Memory: 132.7M
   CGroup: /system.slice/etcd-member.service
           └─2185 /bin/podman run --name etcd --net=host --volume /var/lib/etcd:/etcd-data:z quay.io/coreos/etcd:latest /usr/local/bin/etcd --data-dir /etcd-data --name node1 --initial-advertise-peer-urls http://127.0.0.1:2380 --listen-p
eer-urls http://127.0.0.1:2380 --advertise-client-urls http://127.0.0.1:2379 --listen-client-urls http://127.0.0.1:2379 --initial-cluster node1=http://127.0.0.1:2380

Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.987737 I | raft: b71f75320dc06a6c became candidate at term 2
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.987789 I | raft: b71f75320dc06a6c received MsgVoteResp from b71f75320dc06a6c at term 2
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.987818 I | raft: b71f75320dc06a6c became leader at term 2
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.987833 I | raft: raft.node: b71f75320dc06a6c elected leader b71f75320dc06a6c at term 2
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.989424 I | etcdserver: published {Name:node1 ClientURLs:[http://127.0.0.1:2379]} to cluster 1c45a069f3a1d796
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.989881 I | etcdserver: setting up the initial cluster version to 3.3
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.990222 I | embed: ready to serve client requests
Jan 17 21:19:21 localhost podman[2185]: 2020-01-17 21:19:21.992226 N | embed: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
Jan 17 21:19:22 localhost podman[2185]: 2020-01-17 21:19:22.010502 N | etcdserver/membership: set the initial cluster version to 3.3
Jan 17 21:19:22 localhost podman[2185]: 2020-01-17 21:19:22.010597 I | etcdserver/api: enabled capabilities for version 3.3
```

We can also inspect the state of the container that was run by
the systemd service:

```
[core@localhost ~]$ sudo podman ps -a 
CONTAINER ID  IMAGE                       COMMAND               CREATED         STATUS             PORTS  NAMES
8d58d388b81e  quay.io/coreos/etcd:latest  /usr/local/bin/et...  2  minutes ago  Up 2  minutes ago         etcd
```


```
curl -L -X PUT http://127.0.0.1:2379/v2/keys/foo -d value="bar" | jq .
curl -L http://127.0.0.1:2379/v2/keys/ | jq .
```


boot live ISO

will put you into a bash prompt. - execute `coreos-installer -foo -bar` to do the install  


# Write the script 

Let's say we have a small script we want to run that updates the
issuegen from
[console-login-helper-messages](https://github.com/rfairley/console-login-helper-messages)
to output the node's public IPv4 address on the serial console during
bootup.

Here is the small script:

```nohighlight
#!/bin/bash
echo "Detected Public IPv4: is $(curl https://ipv4.icanhazip.com)" > \
         /run/console-login-helper-messages/issue.d/30_public-ipv4.issue
```

We'll store this script into `/usr/local/bin/public-ipv4.sh` when we
provision the machine.


# Write the systemd unit

We need to call the script we made above by using a systemd unit. Here is
one that works for what we want:

```
[Unit]
Before=console-login-helper-messages-issuegen.service
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/public-ipv4.sh
[Install]
WantedBy=console-login-helper-messages-issuegen.service
```

We'll call this unit `issuegen-public-ipv4.service`.

# Construct the Ignition config

We'll start from a template Ignition config called `config.ign.in`:

**NOTE**: You'll need to substitute in your ssh public key if trying this at home.

```nohighlight
{
  "ignition": {
    "version": "3.0.0"
  },
  "passwd": {
    "users": [
      {
        "name": "core",
        "groups": [
          "sudo"
        ],
        "sshAuthorizedKeys": [
          "ssh-rsa AAAA"
        ]
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "contents": "SYSTEMD_UNIT_CONTENTS",
        "enabled": true,
        "name": "issuegen-public-ipv4.service"
      }
    ]
  },
  "storage": {
    "files": [
      {
        "contents": {
          "source": "data:text/plain;base64,SCRIPT_CONTENTS"
        },
        "mode": 493,
        "overwrite": true,
        "path": "/usr/local/bin/public-ipv4.sh"
      }
    ]
  }
}
```

And then substitute in the two files we created earlier using a small
sed script: 

```nohighlight
$ cat sed.sh 
#!/bin/bash
SCRIPT_CONTENTS=$(base64 --wrap 0 public-ipv4.sh)
SYSTEMD_UNIT_CONTENTS=$(sed 's|$|\\\\n|g' < issuegen-public-ipv4.service | tr -d '\n')
sed -e "s|SYSTEMD_UNIT_CONTENTS|${SYSTEMD_UNIT_CONTENTS}|" \
    -e "s|SCRIPT_CONTENTS|${SCRIPT_CONTENTS}|"
$ bash sed.sh < config.ign.in > config.ign
```

The input Ignition template and the resulting `config.ign` can be downloaded:
[template](/2019-11-06/spec3.config.ign.in) [config.ign](/2019-11-06/spec3.config.ign).

**NOTE** It's always a good idea to run [`ignition-validate`](https://github.com/coreos/ignition#config-validation)
         from the same Ignition version as you are targeting on the configs before booting the instances. 

# Boot an instance

You can then take that Ignition config and boot an instance with it. In my tests
it is working and shows something like the following on the serial console right
before the login prompt:

```nohighlight
SSH host key: SHA256:I/cFFyO5XUOyUw1O5oLLvcvgGzWNhyAPT4O7QKdehgU (ECDSA)
SSH host key: SHA256:3TBdV//KC5pFnyAljGMuMpDlQplBdosz/RwYQUQNSRU (ED25519)
SSH host key: SHA256:x1wkk4/Cc4mq69R5cm41AEzuRnwMXlWkqY8LmpxgFCw (RSA)
eth0: 10.10.10.20 fe80::5054:ff:fe0a:6210
Detected Public IPv4: is 54.91.55.146
localhost login:
```

And the service shows it was launched successfully:

```nohighlight
$ systemctl status issuegen-public-ipv4.service 
● issuegen-public-ipv4.service
   Loaded: loaded (/etc/systemd/system/issuegen-public-ipv4.service; enabled; vendor preset: enabled)
   Active: inactive (dead) since Wed 2019-11-06 17:34:35 UTC; 21min ago
  Process: 1089 ExecStart=/usr/local/bin/public-ipv4.sh (code=exited, status=0/SUCCESS)
 Main PID: 1089 (code=exited, status=0/SUCCESS)

Nov 06 17:34:34 localhost systemd[1]: Starting issuegen-public-ipv4.service...
Nov 06 17:34:34 localhost public-ipv4.sh[1089]:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
Nov 06 17:34:34 localhost public-ipv4.sh[1089]:                                  Dload  Upload   Total   Spent    Left  Speed
Nov 06 17:34:35 localhost public-ipv4.sh[1089]: [237B blob data]
Nov 06 17:34:35 localhost systemd[1]: issuegen-public-ipv4.service: Succeeded.
Nov 06 17:34:35 localhost systemd[1]: Started issuegen-public-ipv4.service.
```

