---
title: "RPM-OSTree Bisecting Helps Track Down Boot Timeout Issue"
tags: [ fedora, atomic ]
date: "2018-10-20"
published: true
---

# Introduction

Last time [I talked about](/2018/06/10/automated-bisect-testing-of-an-entire-os-with-rpm-ostree/)
using [rpm-ostree-bisect](https://raw.githubusercontent.com/ostreedev/ostree-releng-scripts/master/rpm-ostree-bisect),
a tool that I wrote to automatically bisect the history of an
OSTree remote in order to find the exact commit when a problem was
introduced. I recently put the tool to the test again.

# The Problem

Recently a user [reported an issue](https://pagure.io/atomic-wg/issue/513)
where their system was seeing timeouts on boot. They determined
that if they removed the `resume=/dev/mapper/fedora-swap` argument
from the kernel command line then the system would boot without timing
out on the swap device (i.e. an extra 90 seconds added to boot time).

This was interesting because the behavior was actually introduced
during the Fedora 28 cycle (i.e. it was not present in the first
release of Fedora 28 Atomic Host, but showed up sometime over the
life of Fedora 28 Atomic Host). I decided to dig in and do some
investigation. Along the way I realized, admittedly later than I 
than I should have, that I could use `rpm-ostree-bisect` to help
determine exactly where this problem was introduced.

# Automated Bisecting 

OK. First off I needed an easy scriptable test to determine if the
problem exists in a particular commit. In this case it was pretty 
easy; I just needed to search for `Timed out waiting for device`
in the journal for the current boot. My `test.sh`
script ended up looking like:

```nohighlight
[root@localhost ~]# cat /usr/local/bin/test.sh 
#!/bin/bash
if journalctl -b0 | grep 'Timed out waiting for device'; then
    echo "Found device timeout. Test Fails"
    exit 1
else
    echo "Did not find device timeout. Test Passes"
    exit 0
fi
```

I then grabbed the `rpm-ostree-bisect` program from GitHub
and started the bisect. I happened to know at the time one
commit that was good and one that was bad so I added that
information to the `rpm-ostree-bisect` invocation:


```nohighlight
[root@localhost ~]# curl -L https://raw.githubusercontent.com/ostreedev/ostree-releng-scripts/master/rpm-ostree-bisect > /usr/local/bin/rpm-ostree-bisect
[root@localhost ~]# chmod +x /usr/local/bin/rpm-ostree-bisect 
[root@localhost ~]# rpm-ostree-bisect --good 94a9d06eef34aa6774c056356d3d2e024e57a0013b6f8048dbae392a84a137ca --bad 8df48fa2e70ad1952153ae00edbba08ed18b53c3d4095a22985d1085f5203ac6 --testscript /usr/local/bin/test.sh
Using data file at: /var/lib/rpm-ostree-bisect.json
Created symlink /etc/systemd/system/multi-user.target.wants/rpm-ostree-bisect.service → /etc/systemd/system/rpm-ostree-bisect.service.
[root@localhost ~]# reboot 
```

I let it run and when it finished the log from the last run gave me
all of the information I needed:

```nohighlight
[root@localhost ~]# journalctl -b0 -o cat -u rpm-ostree-bisect.service 
Starting RPM-OSTree Bisect Testing...
Using data file at: /var/lib/rpm-ostree-bisect.json
Did not find device timeout. Test Passes
Removed /etc/systemd/system/multi-user.target.wants/rpm-ostree-bisect.service.
BISECT TEST RESULTS:
Last known good commit:
  5736e83 : 28.20180708.0 : 2018-07-08T20:03:31Z
First known bad commit:
  bc3aa17 : 28.20180711.0 : 2018-07-11T18:26:22Z
libostree pull from 'fedora-atomic' for fedora/28/x86_64/atomic-host complete
security: GPG: commit http: TLS
non-delta: meta: 270 content: 0
transfer: secs: 43 size: 2.7 MB
ostree diff commit old: 5736e832b1fd59208465458265136fbe2aa4ba89517d8bdcc91bc84724f40a8e
ostree diff commit new: bc3aa17a5ad6c04103563bd93c4c668996ef786ec04f989a3209a9887c8e982c
Upgraded:
  acl 2.2.52-20.fc28 -> 2.2.53-1.fc28
  attr 2.4.47-23.fc28 -> 2.4.48-1.fc28
  dracut 047-8.git20180305.fc28 -> 048-1.fc28
  dracut-config-generic 047-8.git20180305.fc28 -> 048-1.fc28
  dracut-network 047-8.git20180305.fc28 -> 048-1.fc28
  kernel 4.17.3-200.fc28 -> 4.17.4-200.fc28
  kernel-core 4.17.3-200.fc28 -> 4.17.4-200.fc28
  kernel-modules 4.17.3-200.fc28 -> 4.17.4-200.fc28
  libacl 2.2.52-20.fc28 -> 2.2.53-1.fc28
  libattr 2.4.47-23.fc28 -> 2.4.48-1.fc28
  openldap 2.4.46-1.fc28 -> 2.4.46-2.fc28
  podman 0.6.5-1.git9d97bd6.fc28 -> 0.7.1-1.git802d4f2.fc28
  python3-pytoml 0.1.16-1.fc28 -> 0.1.17-1.fc28
Removed:
  grubby-8.40-11.fc28.x86_64
Added:
  libkcapi-1.1.1-1.fc28.x86_64
  libkcapi-hmaccalc-1.1.1-1.fc28.x86_64
Started RPM-OSTree Bisect Testing.
```


So now we now the exact versions of software that we need to look at that
introduced the problem. I had already suspected dracut and this confirmed
my suspicions even more. Going from `dracut-047` to `dracut-048` introduced
the problem. 

**NOTE**: For anyone interested here is the final [rpm-ostree-bisect.json](/2018-10-20/rpm-ostree-bisect.json) 

# Fin

Having this information ultimately led me to discover that the behavior gets
introduced specifically in the iscsi module of the dracut-network rpm.
I opened [an upstream bug](https://github.com/dracutdevs/dracut/issues/480)
to track the issue further with the dracut maintainers.
