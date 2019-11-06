---
title: 'Running a script on bootup via Ignition'
author: dustymabe
date: 2019-11-06
tags: [ fedora, coreos, ignition ]
published: true
---

# Introduction

With Fedora CoreOS [Ignition](https://github.com/coreos/ignition)
is being used to configure nodes on first boot. While Ignition json
configs are not intended to be a tool that users typically interact
with (we are building tooling like 
[fcct](https://github.com/coreos/fcct) 
for that) I'll show you an example of how to deliver a script to a 
Fedora CoreOS (or RHEL CoreOS) host so that it will be run on first boot.

# Write the script 

Let's say we have a small script we want to run that updates the
issuegen from
[console-login-helper-messages]()
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

# Appendix A: Ignition spec V2

If you are on a platform using Ignition Spec V2 (RHEL CoreOS/OpenShift)
then you
[need a slightly different ignition config](https://github.com/coreos/ignition/blob/master/doc/migrating-configs.md#from-version-230-to-300).
I created a Spec
V2 `config.ign.in` for this example and ran it on RHEL CoreOS to
verify it worked. I have created a Spec V2 version of the template and final 
config: [template](/2019-11-06/spec2.config.ign.in) [config.ign](/2019-11-06/spec2.config.ign).

As always please run
[`ignition-validate`](https://github.com/coreos/ignition#config-validation)
from the same Ignition version as you are targeting on the configs before 
booting the instances. 

# Appendix B: Making the script only run once

If you'd prefer for your script to only run once (for whatever reason) you
can do that too. One very generic way is to lay down a file that can be used
to disable future runs:

```
[Unit]
Before=console-login-helper-messages-issuegen.service
After=network-online.target
ConditionPathExists=!/var/lib/issuegen-public-ipv4
[Service]
Type=oneshot
ExecStart=/usr/local/bin/public-ipv4.sh
ExecStartPost=/usr/bin/touch /var/lib/issuegen-public-ipv4
[Install]
WantedBy=console-login-helper-messages-issuegen.service
```

# Appendix C: Complex directory structures and Ignition

If you have many files you'd like to deliver then you may consider
using a tool like 
[filetranspiler](https://github.com/ashcrow/filetranspiler.git).

You can pass it a base Ignition config (Spec 2 or Spec 3) and it will
output an updated Ignition config with a files section that will work.

For example, if I have a local directory `./fakeroot` with a bunch
of files in it then I can call:

```nohighlight
./filetranspile -i config.ign -f ./fakeroot/ -p -o new-config.ign
```

Enjoy!
