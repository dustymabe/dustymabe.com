---
title: 'Devconf.cz 2020 Fedora CoreOS Lab' 
author: dustymabe
date: 2020-01-23
tags: [ fedora, coreos, ignition ]
draft: false
---

# Setting Up For The Lab

This lab uses a Fedora CoreOS image and several utilities 
(`fcct`, `ignition-validate`) to introduce a user to provisioning
and exploring a Fedora CoreOS system. This lab is written targeting
a Linux environment with a working `libvirt`/`kvm` setup.

To perform this lab you need 
to download the tar archive at 
[this link](https://202001-fedora-coreos-lab.fra1.digitaloceanspaces.com/202001-fedora-coreos-lab.tar.xz)
([signed checksum file](https://202001-fedora-coreos-lab.fra1.digitaloceanspaces.com/202001-fedora-coreos-lab.tar.xz-CHECKSUM))
and extract it.

We recommend extracting it into your home directory like so:

```nohighlight
[host]$ mkdir ~/fcos-lab && cd ~/fcos-lab
[host]$ curl -O -L https://202001-fedora-coreos-lab.fra1.digitaloceanspaces.com/202001-fedora-coreos-lab.tar.xz
[host]$ curl -O -L https://202001-fedora-coreos-lab.fra1.digitaloceanspaces.com/202001-fedora-coreos-lab.tar.xz-CHECKSUM
[host]$ curl https://dustymabe.com/dustymabe.gpg | gpg2 --import
[host]$ gpg2 --verify 202001-fedora-coreos-lab.tar.xz-CHECKSUM
[host]$ sha256sum --check 202001-fedora-coreos-lab.tar.xz-CHECKSUM
[host]$ tar -xf 202001-fedora-coreos-lab.tar.xz
[host]$ gpg2 --verify SHA256-CHECKSUM
[host]$ sha256sum --check SHA256-CHECKSUM
```

We've now downloaded and verified the tarball and the contents of the
tarball after extraction; plaintext inline signatures were verified using
[Dusty Mabe's public GPG key](https://dustymabe.com/dustymabe.gpg).
In this case the included Fedora CoreOS qcow image is the
exact image that was produced by the production Fedora CoreOS release
pipeline and signed by Fedora release engineering. Any time you download
a Fedora CoreOS image it's always good to verify it was signed by Fedora.
We can import the latest release's Fedora GPG key and verify the signature:


```nohighlight
[host]$ curl https://getfedora.org/static/fedora.gpg | gpg2 --import
[host]$ gpg2 --verify fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2.xz.sig
gpg: assuming signed data in 'fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2.xz'
gpg: Signature made Thu 09 Jan 2020 05:56:25 PM EST
gpg:                using RSA key 50CB390B3C3359C4
gpg: Good signature from "Fedora (31) <fedora-31-primary@fedoraproject.org>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 7D22 D586 7F2A 4236 474B  F7B8 50CB 390B 3C33 59C4
```

Now that we've got everything all verified let's decompress the qcow
and also alias the `fcct` and `ignition-validate` binaries so we can
use them in our shell:

```nohighlight
[host]$ unxz fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2.xz
[host]$ alias fcct="${PWD}/fcct"
[host]$ alias ignition-validate="${PWD}/ignition-validate"
```

Now we're all set up and can get started!

# Introduction

Fedora CoreOS is a container focused operating system, coupled with
automatic updates, to enable the next wave of cloud native infrastructure.
Fedora CoreOS is built for many platforms, each of them delivered as a
pre-built disk image. In every environment where
Fedora CoreOS is deployed the initial boot starts with roughly the same
disk image. In cloud environments these are cloud images that were
made specifically for that cloud. For bare metal environments the
[coreos-installer](https://github.com/coreos/coreos-installer)
can be used, which performs a bit for bit copy of the disk image
with some convenience factors added.

If the delivered artifact is a disk image how can it be customized?
The answer to that is [Ignition](https://github.com/coreos/ignition).

Fedora CoreOS uses Ignition to provision a node in an automated fashion.
Ignition config files are written in JSON and typically not user friendly.
For that reason Fedora CoreOS offers the
[Fedora CoreOS Config Transpiler](https://github.com/coreos/fcct)
(also known as FCCT) that will create Ignition configs from a more user
friendly format. Additionally we offer the
[ignition-validate](https://github.com/coreos/ignition#config-validation)
sub-utility that can be used to verify Ignition config and catch
issues before launching a machine.

# First Ignition config via the Fedora CoreOS Config Transpiler

Let's create a very simple FCCT config that will do two things:

- Add a systemd dropin to override the normal `serial-getty@ttyS0.service`.
  The override will make the service automatically log the `core` user in to the
  serial console of the booted machine:
- Place a file at `/etc/zincati/config.d/90-disable-auto-updates.toml` to
  [disable automatic updates](https://github.com/coreos/zincati/blob/master/docs/usage/auto-updates.md#disabling-auto-updates)
  while we poke around the booted machine for the lab.

We can create that FCCT in a file named `fcct-simple.yaml` now:

```nohighlight
[host]$ cat ./fcct-simple.yaml
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
    - path: /etc/zincati/config.d/90-disable-auto-updates.toml
      contents:
        inline: |
          [updates]
          enabled = false
```

We'll then use the `fcct` utility to convert that into an Ignition config:

```nohighlight
[host]$ fcct -pretty -strict -input ./fcct-simple.yaml -output simple.ign
[host]$ cat simple.ign
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
  "storage": {
    "files": [
      {
        "group": {},
        "path": "/etc/zincati/config.d/90-disable-auto-updates.toml",
        "user": {},
        "contents": {
          "source": "data:,%5Bupdates%5D%0Aenabled%20%3D%20false%0A",
          "verification": {}
        }
      }
    ]
  },
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
config after `fcct`, or otherwise providing hand edited Ignition configs you'll want
to always use `ignition-validate` to perform some verification on the config. We'll
do that now to illustrate how:

```nohighlight
[host]$ ignition-validate --version
Ignition 2.1.1
[host]$ ignition-validate ./simple.ign && echo 'success!'
warning at $.storage.files.0.mode, line 18 col 8: permissions unset, defaulting to 0644
success!
```

You'll notice that `ignition-validate` will print out warnings for
common configurations that you may want to fix or change before
proceeding. 

**NOTE:** The config files used for this section can be downloaded
          at the following links:
          [fcct-simple.yaml](/2020-01-23/fcct-simple.yaml),
          [simple.ign](/2020-01-23/simple.ign)
          

# Booting Fedora CoreOS: Simple Provisioning Scenario

Given that we've now created an Ignition config. Let's try to boot a
VM with an image and that config. For this lab we'll use the `qemu` image
but you should be able to use that Ignition config with any of the
artifacts that are published for a Fedora CoreOS release.

In this case we'll use `libvirt`/`qemu`/`kvm` to boot directly into Fedora
CoreOS from the qemu image.

```nohighlight
[host]$ chcon --verbose unconfined_u:object_r:svirt_home_t:s0 simple.ign
[host]$ virt-install --name=fcos --vcpus=2 --ram=2048 --import \
            --network=bridge=virbr0 --graphics=none \
            --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/simple.ign" \
            --disk=size=20,backing_store=${PWD}/fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2
```

**NOTE:** We used `chcon` here to set appropriate SELinux file
          contexts on the Ignition config file so that the resulting
          process would be able to access the file.

This command will start an instance named `fcos` from the 
`fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2` image using the
`simple.ign` Ignition config. It will auto-attach to the
serial console of the machine so you'll be able to see the image
bootup messages. Also of note is that it uses the `backing_store`
option to `virt-install --disk` so it won't write to the downloaded
image, but rather a new disk image that can easily be thrown away.

Once the machine is booted up you should see a few prompts and then
you should be automatically logged in and presented with a bash shell:

```nohighlight
[  OK  ] Started RPM-OSTree System Management Daemon.

Fedora CoreOS preview 31.20200108.3.0
Kernel 5.4.7-200.fc31.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:xIVCnEx8x8cfiwijGLOs+iaojfVs/Nkt//ZEcM2i/EY (ED25519)
SSH host key: SHA256:X7bMVcuHFqIQRrSINdyLJ+flbTPSpGVlw8sRD+ZtR44 (ECDSA)
SSH host key: SHA256:Z5M6SZMVFQ1fDqp6tTcbj+oFmurOB2z1ioZKSifYRSI (RSA)
eth0: 192.168.122.20 fe80::5054:ff:feb2:e7f9
localhost login: core (automatic login)

[core@localhost ~]$
```

Magic? Yes! The systemd dropin was created and we were automatically logged
in to the terminal. You can see the full configuration for `serial-getty@ttyS0.service`
by using `systemctl cat serial-getty@ttyS0.service`.

We can also check that the zincati configuration file got created by Ignition:

```nohighlight
$ cat /etc/zincati/config.d/90-disable-auto-updates.toml
[updates]
enabled = false
```

### Exploring Fedora CoreOS Internals

Once you have access to the console of the machine you can browse around a bit
to see some of the different pieces of the operating system. For example, even
though this is an OSTree based system it was still composed via RPMs
and you can inspect the system to see what it was composed of by using `rpm`:

```nohighlight
$ rpm -q ignition kernel moby-engine podman systemd rpm-ostree zincati
ignition-2.1.1-3.git40c0b57.fc31.x86_64
kernel-5.4.7-200.fc31.x86_64
moby-engine-18.09.8-2.ce.git0dd43dd.fc31.x86_64
podman-1.6.2-2.fc31.x86_64
systemd-243.5-1.fc31.x86_64
rpm-ostree-2019.7-1.fc31.x86_64
zincati-0.0.6-1.fc31.x86_64
```

You can also inspect the current revision of Fedora CoreOS:

```nohighlight
$ rpm-ostree status
State: idle
AutomaticUpdates: disabled
Deployments:
* ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200108.3.0 (2020-01-09T21:51:07Z)
                    Commit: 113aa27efe1bbcf6324af7423f64ef7deb0acbf21b928faec84bf66a60a5c933
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4
```

And check on `zincati.service`, which communicates with our update server and
tells `rpm-ostree` when to do an update and to what version to update to:

```nohighlight
$ systemctl status zincati.service | cat
● zincati.service - Zincati Update Agent
   Loaded: loaded (/usr/lib/systemd/system/zincati.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2020-01-20 20:01:11 UTC; 2min 9s ago
     Docs: https://github.com/coreos/zincati
 Main PID: 1063 (zincati)
    Tasks: 2 (limit: 2297)
   Memory: 11.4M
   CGroup: /system.slice/zincati.service
           └─1063 /usr/libexec/zincati agent -v

Jan 20 20:01:11 localhost systemd[1]: Started Zincati Update Agent.
Jan 20 20:01:11 localhost zincati[1063]: [INFO ] starting update agent (zincati 0.0.6)
Jan 20 20:01:14 localhost zincati[1063]: [INFO ] Cincinnati service: https://updates.coreos.stg.fedoraproject.org
Jan 20 20:01:14 localhost zincati[1063]: [INFO ] agent running on node 'ead8e3b8ead045dcb36c04bc7be0acbc', in update group 'default'
Jan 20 20:01:14 localhost zincati[1063]: [WARN ] initialization complete, auto-updates logic disabled by configuration
```

**NOTE:** You can see from the *"auto-updates logic disabled by configuration"* message that 
          `zincati` properly picked up the configuration to disable updates that was placed
          in `/etc/zincati/config.d/90-disable-auto-updates.toml`.

One other interesting thing to do is view the logs from Ignition in case
there is anything interesting there you may want to investigate:

```nohighlight
$ journalctl -t ignition | cat
```

And finally, of course you can use the `docker` (provided by `moby-engine` rpm)
or `podman` commands to inspect the current state of containers on the system:

```nohighlight
$ podman version
$ podman info
$ sudo docker info
$ sudo docker version
```

**NOTE:** You need `sudo` for docker commands. `podman` commands can be run as 
          root or as a non-root user.

**NOTE:** Running a `docker` command will cause the docker daemon to be started
          if it was not already started.

### Taking down the Virtual Machine

Let's now get rid of that VM so we can start again from scratch. First
escape out of the serial console by pressing `CTRL` + `]` and then type:

```nohighlight
[host]$ virsh destroy fcos
[host]$ virsh undefine --remove-all-storage fcos
```

# Booting Fedora CoreOS: Intermediate Provisioning Scenario

For a more intermediate provisioning scenario let's add an SSH key to
our `authorized_keys` file and run a script on the first boot. We'll
add to the `fcct` config from the previous scenario such that the
provisioning configuration will now tell Ignition to:

- Add a systemd dropin for auto login from serial console.
- Disable automatic updates.
- Add a script at `/usr/local/bin/public-ipv4.sh` to run on boot.
- Configure a systemd service to run the script on first boot.

### Write the Script

So what script should we run? Here's a good small script:

```nohighlight
#!/bin/bash
echo "Detected Public IPv4: is $(curl https://ipv4.icanhazip.com)" > \
         /run/console-login-helper-messages/issue.d/30_public-ipv4.issue
```

This script uses [icanhazip.com](https://icanhazip.com) to update 
the issuegen from
[console-login-helper-messages](https://github.com/rfairley/console-login-helper-messages)
to output the node's public IPv4 address on the serial console during
bootup. This is useful in cloud environments when you might have different
public and private addresses.

We'll store this script into `/usr/local/bin/public-ipv4.sh` when we
provision the machine. We'll encode it into an FCCT config here shortly.

### Write the Systemd Service

We need to call the script from the previous section by using a systemd unit.
Here is one that works for what we want, which is to execute on first boot and not
again:

```nohighlight
[Unit]
Before=console-login-helper-messages-issuegen.service
After=network-online.target
ConditionPathExists=!/var/lib/issuegen-public-ipv4
[Service]
Type=oneshot
ExecStart=/usr/local/bin/public-ipv4.sh
ExecStartPost=/usr/bin/touch /var/lib/issuegen-public-ipv4
RemainAfterExit=yes
[Install]
WantedBy=console-login-helper-messages-issuegen.service
```

We'll call this unit `issuegen-public-ipv4.service` and we'll embed it
into the FCCT config in the next section.

### Write FCCT and convert to Ignition

The final FCCT for what we want to do is shown below. We'll
store these contents in `fcct-intermediate.yaml`.

```nohighlight
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
    - name: issuegen-public-ipv4.service
      enabled: true
      contents: |
        [Unit]
        Before=console-login-helper-messages-issuegen.service
        After=network-online.target
        ConditionPathExists=!/var/lib/issuegen-public-ipv4
        [Service]
        Type=oneshot
        ExecStart=/usr/local/bin/public-ipv4.sh
        ExecStartPost=/usr/bin/touch /var/lib/issuegen-public-ipv4
        RemainAfterExit=yes
        [Install]
        WantedBy=console-login-helper-messages-issuegen.service
storage:
  files:
    - path: /etc/zincati/config.d/90-disable-auto-updates.toml
      contents:
        inline: |
          [updates]
          enabled = false
    - path: /usr/local/bin/public-ipv4.sh
      mode: 0755
      contents:
        inline: |
          #!/bin/bash
          echo "Detected Public IPv4: is $(curl https://ipv4.icanhazip.com)" > \
              /run/console-login-helper-messages/issue.d/30_public-ipv4.issue
```

And then convert to Igntion:

```nohighlight
[host]$ fcct -pretty -strict -input ./fcct-intermediate.yaml -output intermediate.ign
```

**NOTE:** The config files used for this section can be downloaded
          at the following links:
          [fcct-intermediate.yaml](/2020-01-23/fcct-intermediate.yaml),
          [intermediate.ign](/2020-01-23/intermediate.ign)


### Test it out

Just as before we'll use the following to boot the instance:

```nohighlight
[host]$ chcon --verbose unconfined_u:object_r:svirt_home_t:s0 intermediate.ign
[host]$ virt-install --name=fcos --vcpus=2 --ram=2048 --import \
            --network=bridge=virbr0 --graphics=none \
            --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/intermediate.ign" \
            --disk=size=20,backing_store=${PWD}/fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2
```

And view on the serial console that the `Detected Public IPv4` is
shown in the serial console output right before you're dropped to a
login prompt:

```nohighlight
Fedora CoreOS preview 31.20200108.3.0
Kernel 5.4.7-200.fc31.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:HjI751SUuZsyWCvB1wxMAUC9dIrLHAnHMSW29jg18L8 (ECDSA)
SSH host key: SHA256:mI2NIFl6zJiPT9GYpdXqTn04kcMjMGnJTpIvmS0boB4 (ED25519)
SSH host key: SHA256:xfGDX5sxQ+ieE61sO1/H5KcmDNGW0YltVb6VCeZMMIQ (RSA)
eth0: 192.168.122.88 fe80::5054:ff:fe4e:c37d
Detected Public IPv4: is 54.91.55.146
localhost login: core (automatic login)

[core@localhost ~]$
```

And the service shows it was launched successfully:

```nohighlight
$ systemctl status issuegen-public-ipv4.service | cat
● issuegen-public-ipv4.service
   Loaded: loaded (/etc/systemd/system/issuegen-public-ipv4.service; enabled; vendor preset: enabled)
   Active: active (exited) since Mon 2020-01-20 20:57:04 UTC; 3min 21s ago
  Process: 1118 ExecStart=/usr/local/bin/public-ipv4.sh (code=exited, status=0/SUCCESS)
  Process: 1205 ExecStartPost=/usr/bin/touch /var/lib/issuegen-public-ipv4 (code=exited, status=0/SUCCESS)
 Main PID: 1118 (code=exited, status=0/SUCCESS)

Jan 20 20:57:03 localhost systemd[1]: Starting issuegen-public-ipv4.service...
Jan 20 20:57:03 localhost public-ipv4.sh[1118]:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
Jan 20 20:57:03 localhost public-ipv4.sh[1118]:                                  Dload  Upload   Total   Spent    Left  Speed
Jan 20 20:57:04 localhost public-ipv4.sh[1118]: [237B blob data]
Jan 20 20:57:04 localhost systemd[1]: Started issuegen-public-ipv4.service.
```

Now let's take down the instance for the next test. First, disconnect 
from the serial console by pressing `CTRL` + `]` and then destroy the
machine:

```nohighlight
[host]$ virsh destroy fcos
[host]$ virsh undefine --remove-all-storage fcos
```

# Booting Fedora CoreOS: Advanced Provisioning Scenario

So what is running a server all about? Hosting services, crunching data,
mining bitcoin? **DING DING DING**! Let's actually do something with our Fedora
CoreOS node.

Since Fedora CoreOS is focused on running applications/services in
containers we recommend trying to only run containers and not modifying the
host directly. This makes automatic updates more reliable and allows for
separation of concerns with the Fedora CoreOS team responsible for the OS and
end-user operators/sysadmins responsible for the applications.

In this case let's do a few more things. As usual we'll do the autologin and
disabling of updates, but we'll also:

- Add an SSH key for the `core` user.
- Add a systemd service (`failure.service`) that fails on boot.
- Add a systemd service that will use a container to bring up a hosted service.


We'll create this config in a file called `./fcct-advanced.yaml`

```nohighlight
[host]$ cat fcct-advanced.yaml
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
storage:
  files:
    - path: /etc/zincati/config.d/90-disable-auto-updates.toml
      contents:
        inline: |
          [updates]
          enabled = false
```

*Optional*: You can replace the SSH pubkey in the yaml file with your
            own public key so you can log in to the booted instance.
            If you choose not to do this you'll still be auto logged
            in to the serial console.

Run `fcct` to convert that to an Ignition config:

```nohighlight
[host]$ fcct -pretty -strict -input ./fcct-advanced.yaml -output advanced.ign
```

**NOTE:** The config files used for this section can be downloaded
          at the following links:
          [fcct-advanced.yaml](/2020-01-23/fcct-advanced.yaml),
          [advanced.ign](/2020-01-23/advanced.ign)



```nohighlight
[host]$ chcon --verbose unconfined_u:object_r:svirt_home_t:s0 advanced.ign
[host]$ virt-install --name=fcos --vcpus=2 --ram=2048 --import \
            --network=bridge=virbr0 --graphics=none \
            --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/advanced.ign" \
            --disk=size=20,backing_store=${PWD}/fedora-coreos-31.20200108.3.0-qemu.x86_64.qcow2
```

On the serial console you see:

```nohighlight
Fedora CoreOS preview 31.20200108.3.0
Kernel 5.4.7-200.fc31.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:bA3Gzr14lUU740T8Ib8XXpgggN/desPPyyLSd93n0Vk (ED25519)
SSH host key: SHA256:o7p+qOEh5zWRszRwUlLY/uxftz5v4QxuYFTEoJO7UqY (ECDSA)
SSH host key: SHA256:mRXimZXpHhieyPcHOU8DK3sKDIwC2nihSOV6WNjPZJw (RSA)
eth0: 192.168.122.163 fe80::5054:ff:fe73:6081
localhost login: core (automatic login)

[systemd]
Failed Units: 1
  failure.service
```

If you'd like to connect via SSH disconnect from the serial console by
pressing `CTRL` + `]` and then use the reported IP address for `eth0`
from the serial console to log in using the `core` user via SSH:

```nohighlight
$ ssh core@192.168.122.163
The authenticity of host '192.168.122.163 (192.168.122.163)' can't be established.
ECDSA key fingerprint is SHA256:OAmR5Ab5eH9eZHC+D1gYmRsoUgJ/jufTNArrskBCxr4.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.122.163' (ECDSA) to the list of known hosts.
Fedora CoreOS preview 31.20200108.3.0
Tracker: https://github.com/coreos/fedora-coreos-tracker
Preview release: breaking changes may occur

Last login: Mon Jan 20 22:15:10 2020
[systemd]
Failed Units: 1
  failure.service
```

The `Failed Units` message is coming from the
[console login helper messages](https://github.com/rfairley/console-login-helper-messages)
helpers. This particular helper shows us when `systemd` has services
that are in a failed state. In this case we made `failure.service`
with `ExecStart=/usr/bin/false`, so we intentionally created a service
that will always fail in order to illustrate the helper messages.

Now that we're up and we don't have any *real* failures we can check
out our service we care about (`etcd-member.service`):

```nohighlight
$ systemctl status etcd-member.service
● etcd-member.service - Run single node etcd
   Loaded: loaded (/etc/systemd/system/etcd-member.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2020-01-20 22:15:09 UTC; 4min 5s ago
  Process: 1144 ExecStartPre=/usr/bin/mkdir -p /var/lib/etcd (code=exited, status=0/SUCCESS)
  Process: 1153 ExecStartPre=/bin/podman kill etcd (code=exited, status=125)
  Process: 1356 ExecStartPre=/bin/podman rm etcd (code=exited, status=1/FAILURE)
  Process: 1396 ExecStartPre=/bin/podman pull quay.io/coreos/etcd (code=exited, status=0/SUCCESS)
 Main PID: 1971 (podman)
    Tasks: 10 (limit: 2297)
   Memory: 115.7M
   CGroup: /system.slice/etcd-member.service
           └─1971 /bin/podman run --name etcd --net=host --volume /var/lib/etcd:/etcd-data:z quay.io/coreos/etcd:latest /usr/local/bin/etcd --data-dir /etcd-data --name node1 --initial-adv>

Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.486290 I | raft: b71f75320dc06a6c became candidate at term 2
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.486327 I | raft: b71f75320dc06a6c received MsgVoteResp from b71f75320dc06a6c at term 2
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.486344 I | raft: b71f75320dc06a6c became leader at term 2
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.486351 I | raft: raft.node: b71f75320dc06a6c elected leader b71f75320dc06a6c at term 2
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.486698 I | etcdserver: published {Name:node1 ClientURLs:[http://127.0.0.1:2379]} to cluster 1c45a069f3a1d796
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.487238 I | etcdserver: setting up the initial cluster version to 3.3
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.487310 I | embed: ready to serve client requests
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.488046 N | embed: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.498083 N | etcdserver/membership: set the initial cluster version to 3.3
Jan 20 22:15:10 localhost podman[1971]: 2020-01-20 22:15:10.498521 I | etcdserver/api: enabled capabilities for version 3.3
```

We can also inspect the state of the container that was run by
the systemd service:

```nohighlight
$ sudo podman ps -a
CONTAINER ID  IMAGE                       COMMAND               CREATED        STATUS            PORTS  NAMES
85cf5d500626  quay.io/coreos/etcd:latest  /usr/local/bin/et...  4 minutes ago  Up 4 minutes ago         etcd
```

And we can set a key/value pair in etcd. For now let's set the key
`fedora` to the value `fun`:

```nohighlight
$ curl -L -X PUT http://127.0.0.1:2379/v2/keys/fedora -d value="fun"
{"action":"set","node":{"key":"/fedora","value":"fun","modifiedIndex":4,"createdIndex":4}}
$ curl -L http://127.0.0.1:2379/v2/keys/ 2>/dev/null | jq .
{
  "action": "get",
  "node": {
    "dir": true,
    "nodes": [
      {
        "key": "/fedora",
        "value": "fun",
        "modifiedIndex": 4,
        "createdIndex": 4
      }
    ]
  }
}
```

Looks like everything is working!

# Updates!

So far we've been disabling one of the best features of Fedora CoreOS: 
automatic updates. Let's see them in action.

We can do this by removing the `zincati` config that is disabling the
updates and restarting the zincati service:

```nohighlight
$ sudo rm /etc/zincati/config.d/90-disable-auto-updates.toml 
$ sudo systemctl restart zincati.service
Connection to 192.168.122.163 closed.
```

After restarting `zincati.service` the machine will reboot after a
short period of time. In this case the update has been staged and
the system rebooted in order to boot into the new deployment with
the latest software.

When we log back in we can view the current version of Fedora CoreOS
is now `31.20200113.3.1`. The `rpm-ostree status` output will also
how the older version, which still exists in case we need to rollback:

```nohighlight
$ rpm-ostree status
State: idle
AutomaticUpdates: disabled
Deployments:
● ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200113.3.1 (2020-01-14T00:20:15Z)
                    Commit: f480038412cba26ab010d2cd5a09ddec736204a6e9faa8370edaa943cf33c932
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4

  ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200108.3.0 (2020-01-09T21:51:07Z)
                    Commit: 113aa27efe1bbcf6324af7423f64ef7deb0acbf21b928faec84bf66a60a5c933
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4
```

**NOTE:** The currently booted deployment is denoted by the `●` character.

You can view the differences between the two versions by running an `rpm-ostree db diff`
command:

```nohighlight
$ rpm-ostree db diff 113aa27efe1bbcf6324af7423f64ef7deb0acbf21b928faec84bf66a60a5c933 f480038412cba26ab010d2cd5a09ddec736204a6e9faa8370edaa943cf33c932
ostree diff commit from: 113aa27efe1bbcf6324af7423f64ef7deb0acbf21b928faec84bf66a60a5c933
ostree diff commit to:   f480038412cba26ab010d2cd5a09ddec736204a6e9faa8370edaa943cf33c932
Upgraded:
  bind-libs 32:9.11.13-3.fc31 -> 32:9.11.14-2.fc31
  ...
```

If the system is not functioning fully for whatever reason we can go back to the previous version:

```nohighlight
$ sudo rpm-ostree rollback --reboot
```

After logging back in after reboot we can see we are now booted back into the old
`31.20200108.3.0` deployment from before the upgrade occurred:

```nohighlight
$ rpm-ostree status 
State: idle
AutomaticUpdates: disabled
Deployments:
● ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200108.3.0 (2020-01-09T21:51:07Z)
                    Commit: 113aa27efe1bbcf6324af7423f64ef7deb0acbf21b928faec84bf66a60a5c933
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4

  ostree://fedora:fedora/x86_64/coreos/stable
                   Version: 31.20200113.3.1 (2020-01-14T00:20:15Z)
                    Commit: f480038412cba26ab010d2cd5a09ddec736204a6e9faa8370edaa943cf33c932
              GPGSignature: Valid signature by 7D22D5867F2A4236474BF7B850CB390B3C3359C4

```

# Conclusion

In this lab we've learned a little bit about Fedora CoreOS. We've
learned how it's delivered as a pre-created disk image, how it's 
provisioned in an automated fashion via Ignition, and also how
automated updates are configured and achieved via zincati and
RPM-OSTree. The next step is to try out Fedora CoreOS for your
own use cases and
[join the community](https://github.com/coreos/fedora-coreos-tracker/blob/master/README.md#communication-channels-for-fedora-coreos)!


