---
title: 'Automating a Custom Install of Fedora CoreOS'
author: dustymabe
date: 2020-04-04
tags: [ fedora, coreos, coreos-installer ]
draft: false
---

# Introduction

With Fedora CoreOS we currently have two ways to do a bare metal
install and get our disk image onto the spinning rust of a "non-cloud"
server. You can
[use `coreos.inst*` kernel arguments to automate the install](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_installing_from_pxe),
or you can
[boot the Live ISO and get a bash prompt](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_installing_from_live_iso)
where you can then run `coreos-installer` directly after doing whatever
hardware/network discovery that is necessary. This means you either
do a simple automated install where you provide all of the information
up front or you are stuck doing something interactive. However,
because we use a Live ISO that boots full Fedora CoreOS there is
a third option.

A "Live" environment is a booted environment that is loaded from a squashfs
filesystem and runs entirely from RAM. For Fedora CoreOS we produce a
Live ISO and a Live PXE initramfs/kernel. Either of these can be used
as an installer for Fedora CoreOS (i.e. write image to disk and reboot)
or to run containerized workloads on servers where the root filesystem runs
completely from RAM. Because we use a Live environment that **is**
Fedora CoreOS we can use Ignition to automate a complex install,
encoding whatever logic we desire into the automation.


# An Example of a Custom Install FCCT/Ignition config

For the `coreos-installer` tool we've had several reasonable requests for
features to add that seem harmless. However, if we add a new feature
here for this user's environment/workflow and one there for that user's
environment/workflow, we eventually get a feature set that is
confusing and less maintainable. In this example I'll handle the
following two special use cases that a user recently presented:

- user has a fleet of hardware that is mostly homogeneous except a
  few machines have `/dev/nvme0` instead of `/dev/sda`. They'd like
  to use the same FCCT/Ignition config for all machines.
- user would like to ping a URL after the install is complete in order
  to let their provisioning system know the install was successful.
  This is a [common feature request](https://github.com/coreos/coreos-installer/issues/21).


To get this special functionality we essentially want to
[tell Ignition to run a script on boot](/2019/11/06/running-a-script-on-bootup-via-ignition/)
where this script will implement the custom logic that decides what
block device to install to and after the install will ping a URL to
report back success or failure to a provisioning service. Here's one such
example script that will do the trick:

```nohighlight
#!/usr/bin/bash
set -x
poststatus() {
    status=$1
    curl -X POST "https://httpbin.org/anything/install=${status}"
}
main() {
    # Hardcoded values the config.ign file is written out
    # by the Ignition run when the Live environment is booted
    ignition_file='/home/core/config.ign'
    # Image url should be wherever our FCOS image is stored
    # Note you'll want to use https and also copy the image .sig
    # to the appropriate place. Otherwise you'll need to `--insecure`
    image_url='https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz'
    # Some custom arguments for firstboot
    firstboot_args='console=tty0'

    # Dynamically detect which device to install to.
    # This represents something an admin may want to do to share the
    # same installer automation across various hardware.
    if [ -b /dev/sda ]; then
        install_device='/dev/sda'
    elif [ -b /dev/nvme0 ]; then
        install_device='/dev/nvme0'
    else
        echo "Can't find appropriate device to install to" 1>&2
        poststatus 'failure'
        return 1
    fi

    # Call out to the installer and use curl to ping a URL
    # In some provisioning environments it can be useful to
    # post some status information to the environment to let
    # it know the install completed successfully.
    cmd="coreos-installer install --firstboot-args=${firstboot_args}"
    cmd+=" --image-url ${image_url} --ignition=${ignition_file}"
    cmd+=" ${install_device}"
    if $cmd; then
        echo "Install Succeeded!"
        poststatus 'success'
        return 0
    else
        echo "Install Failed!"
        poststatus 'failure'
        return 1
    fi
}
main
```

In this script we tell `coreos-installer` to embed the Ignition
config at `/home/core/config.ign` into the installed system to be
executed on next boot. It's important to note here that we are going
to be using two different Ignition configs during this exercise:

- One to automate the install during boot of the Live system
- One to provision the installed system on first boot from hard disk

In this case `/home/core/config.ign` is the config for provisioning
the installed system on first boot from hard disk. We'll need to define
that Ignition config and write it to `/home/core/config.ign` during
the boot of the Live system (the install environment). The simplest
example Ignition config that works anywhere (meaning anyone reading
this post can copy/paste it and it will work) is one for doing an
autologin on the VGA console of the machine:

```nohighlight
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
        "name": "getty@tty1.service"
      }
    ]
  }
}
```

OK now we've got a script to automate the install and also an Ignition
config to provision the installed system on its first boot. Now we
just need a systemd unit that will run the script. This should do:

```nohighlight
[Unit]
After=network-online.target
Wants=network-online.target
Before=systemd-user-sessions.service
OnFailure=emergency.target
OnFailureJobMode=replace-irreversibly

[Service]
RemainAfterExit=yes
Type=oneshot
ExecStart=/usr/local/bin/run-coreos-installer
ExecStartPost=/usr/bin/systemctl --no-block reboot
StandardOutput=kmsg+console
StandardError=kmsg+console

[Install]
WantedBy=multi-user.target
```

In here we'll run the script (which we're going to place at
the path `/usr/local/bin/run-coreos-installer`) and then we
call `systemctl --no-block reboot` to reboot the system in
an `ExecStartPost`.

Putting it all together we end up with the following FCCT:

```nohighlight
variant: fcos
version: 1.0.0
systemd:
  units:
  - name: run-coreos-installer.service
    enabled: true
    contents: |
      [Unit]
      After=network-online.target
      Wants=network-online.target
      Before=systemd-user-sessions.service
      OnFailure=emergency.target
      OnFailureJobMode=replace-irreversibly
      [Service]
      RemainAfterExit=yes
      Type=oneshot
      ExecStart=/usr/local/bin/run-coreos-installer
      ExecStartPost=/usr/bin/systemctl --no-block reboot
      StandardOutput=kmsg+console
      StandardError=kmsg+console
      [Install]
      WantedBy=multi-user.target
storage:
  files:
    - path: /usr/local/bin/run-coreos-installer
      mode: 0755
      contents:
        inline: |
          #!/usr/bin/bash
          set -x
          poststatus() {
              status=$1
              curl -X POST "https://httpbin.org/anything/install=${status}"
          }
          main() {
              # Hardcoded values the config.ign file is written out
              # by the Ignition run when the Live environment is booted
              ignition_file='/home/core/config.ign'
              # Image url should be wherever our FCOS image is stored
              # Note you'll want to use https and also copy the image .sig
              # to the appropriate place. Otherwise you'll need to `--insecure`
              image_url='https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz'
              # Some custom arguments for firstboot
              firstboot_args='console=tty0'
              # Dynamically detect which device to install to.
              # This represents something an admin may want to do to share the
              # same installer automation across various hardware.
              if [ -b /dev/sda ]; then
                  install_device='/dev/sda'
              elif [ -b /dev/nvme0 ]; then
                  install_device='/dev/nvme0'
              else
                  echo "Can't find appropriate device to install to" 1>&2
                  poststatus 'failure'
                  return 1
              fi
              # Call out to the installer and use curl to ping a URL
              # In some provisioning environments it can be useful to
              # post some status information to the environment to let
              # it know the install completed successfully.
              cmd="coreos-installer install --firstboot-args=${firstboot_args}"
              cmd+=" --image-url ${image_url} --ignition=${ignition_file}"
              cmd+=" ${install_device}"
              if $cmd; then
                  echo "Install Succeeded!"
                  poststatus 'success'
                  return 0
              else
                  echo "Install Failed!"
                  poststatus 'failure'
                  return 1
              fi
          }
          main
    - path: /home/core/config.ign
      # A basic Ignition config that will enable autologin on tty1
      contents:
        inline: |
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
                  "name": "getty@tty1.service"
                }
              ]
            }
          }
```

**NOTE** The fcct config and generated Ignition config from this example can be found at
         the following links: [automated_install.yaml](/2020-04-04/automated_install.yaml),
         [automated_install.ign](/2020-04-04/automated_install.ign).

There are two ways to now run the automated install:

- Run an install via PXE
- Run an install using the Live ISO with an embedded Ignition config

We'll do both in the following sections.

# Running the Install via PXE

To test out the PXE install I can
[use Libvirt/iPXE to easily test an install](/2019/01/04/easy-pxe-boot-testing-with-only-http-using-ipxe-and-libvirt/).
After copying down the live kernel/initramfs images locally I created
the following ipxe config:

```nohighlight
#!ipxe
set base-url http://192.168.122.1:8000
kernel ${base-url}/fedora-coreos-31.20200310.3.0-live-kernel-x86_64 ip=dhcp rd.neednet=1 console=tty0 ignition.firstboot ignition.platform.id=metal ignition.config.url=https://dustymabe.com/2020-04-04/automated_install.ign
initrd ${base-url}/fedora-coreos-31.20200310.3.0-live-initramfs.x86_64.img
boot
```

Then I can launch a VM and watch the automated install:

```nohighlight
$ virt-install --name pxe --network bridge=virbr0 --memory 4096 --disk size=20 --pxe
```

**NOTE** I'm executing libvirt in session mode (unprivileged). `virbr0` is the name
         of the bridge that is part of libvirt's `default` network that is configured
         with `<bootp file='http://192.168.122.1:8000/boot.ipxe'/>`. 

After some time we should see the script run to perform the install:

```nohighlight
[   16.482715] run-coreos-installer[1039]: + main
[   16.483913] run-coreos-installer[1039]: + ignition_file=/home/core/config.ign
[   16.485477] run-coreos-installer[1039]: + image_url=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz
[   16.488662] run-coreos-installer[1039]: + firstboot_args=console=tty0
[   16.490163] run-coreos-installer[1039]: + '[' -b /dev/sda ']'
[   16.491670] run-coreos-installer[1039]: + install_device=/dev/sda
[   16.493560] run-coreos-installer[1039]: + cmd='coreos-installer install --firstboot-args=console=tty0'
[   16.495867] run-coreos-installer[1039]: + cmd+=' --image-url https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz --ignition=/home/core/config.ign'
[   16.499662] run-coreos-installer[1039]: + cmd+=' /dev/sda'
[   16.501331] run-coreos-installer[1039]: + coreos-installer install --firstboot-args=console=tty0 --image-url https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz --ignition=/home/core/config.ign /dev/sda
[   16.585499] run-coreos-installer[1039]: Downloading image from https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz
[   16.589499] run-coreos-installer[1039]: Downloading signature from https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200310.3.0/x86_64/fedora-coreos-31.20200310.3.0-metal.x86_64.raw.xz.sig
[  154.462948] run-coreos-installer[1039]: gpg: Signature made Wed Mar 25 21:24:20 2020 UTC
[  154.462948] run-coreos-installer[1039]: gpg: using RSA key 50CB390B3C3359C4
[  154.465332] run-coreos-installer[1039]: gpg: Good signature from "Fedora (31) <fedora-31-primary@fedoraproject.org>" [ultimate]
[  160.248664] run-coreos-installer[1039]: > Read disk 454.1 MiB/454.1 MiB (100%)
[  160.739264] run-coreos-installer[1039]: Writing Ignition config
[  160.743489] run-coreos-installer[1039]: Writing first-boot kernel arguments
[  160.773680] run-coreos-installer[1039]: Install complete.
[  160.790072] run-coreos-installer[1039]: + echo 'Install Succeeded!'
[  160.791952] run-coreos-installer[1039]: Install Succeeded!
[  160.793589] run-coreos-installer[1039]: + poststatus success
[  160.795330] run-coreos-installer[1039]: + status=success
[  160.797023] run-coreos-installer[1039]: + curl -X POST https://httpbin.org/anything/install=success
[  160.830473] run-coreos-installer[1039]:   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
[  160.834620] run-coreos-installer[1039]:                                  Dload  Upload   Total   Spent    Left  Speed
[  160.834620] run-coreos-installer[1039]: 100   359  100   359    0     0   1424      0 --:--:-- --:--:-- --:--:--  1418
[  161.090987] run-coreos-installer[1039]: {
[  161.091879] run-coreos-installer[1039]:   "args": {},
[  161.092825] run-coreos-installer[1039]:   "data": "",
[  161.093779] run-coreos-installer[1039]:   "files": {},
[  161.095073] run-coreos-installer[1039]:   "form": {},
[  161.096364] run-coreos-installer[1039]:   "headers": {
[  161.097661] run-coreos-installer[1039]:     "Accept": "*/*",
[  161.099086] run-coreos-installer[1039]:     "Host": "httpbin.org",
[  161.101506] run-coreos-installer[1039]:     "User-Agent": "curl/7.66.0",
[  161.103028] run-coreos-installer[1039]:     "X-Amzn-Trace-Id": "Root=1-5e8821bf-a135b8e0c8bf3840a56d3400"
[  161.105043] run-coreos-installer[1039]:   },
[  161.106237] run-coreos-installer[1039]:   "json": null,
[  161.107865] run-coreos-installer[1039]:   "method": "POST",
[  161.109504] run-coreos-installer[1039]:   "origin": "99.92.55.146",
[  161.110997] run-coreos-installer[1039]:   "url": "https://httpbin.org/anything/install=success"
[  161.113213] run-coreos-installer[1039]: }
[  161.119615] run-coreos-installer[1039]: + return 0
```

The system then reboots and runs the second Ignition provisioning config on
the first boot of the installed system. As a result of that config getting
applied the console on `tty1` (VGA console) should be logged into by default.


# Running the Install via an Embedded Ignition config in the Live ISO

The [`coreos-installer`](https://github.com/coreos/coreos-installer)
tool supports embedding a provided Ignition config
into the Live ISO image so that a user can gain an automated workflow without
having to catch the grub/isolinux prompts in order to specify an `ignition.config.url`
on the kernel command line.

We can use this feature in order to automate an install using the Live ISO
image as well. After downloading the ISO (in this case
`fedora-coreos-31.20200310.3.0-live.x86_64.iso`) you can embed the Ignition config
like so:

```nohighlight
$ coreos-installer iso embed --config automated_install.ign ./fedora-coreos-31.20200310.3.0-live.x86_64.iso
```

Now if we boot the ISO it will apply the Ignition config which will
run the install:

```nohighlight
$ virt-install --name cdrom --network bridge=virbr0 --memory 4096 --disk size=20 --cdrom ./fedora-coreos-31.20200310.3.0-live.x86_64.iso
```

The install will proceed exactly the same as in the Live PXE case
above and the user will eventually be logged in on the VGA console
of the machine.


# Conclusion

While there is a simple automation workflow for the installer using
kernel arguments, there is a much more powerful option for users who
need it. Using an Ignition config plus the full Fedora CoreOS live
environment provided by our Live ISO/PXE artifacts give the user all
the flexibility he or she may need when running a custom install of
Fedora CoreOS.

Happy installing!
