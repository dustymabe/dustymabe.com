---
title: "Automated Bisect Testing Of An Entire OS with RPM-OSTree"
tags: [ fedora, atomic ]
date: "2018-06-10"
published: true
---

# Introduction

Occasionally in OS land we'll come across a bug that snuck its way
into a build and has been in the wild for a while before anyone
notices it. One example is a 
[recent bug](https://bugzilla.redhat.com/show_bug.cgi?id=1584216) 
(originally [discovered](https://github.com/coreos/bugs/issues/2443)
 by the community of CoreOS Container Linux) where the jumbo
packet `MTU` size of `9001` was no longer getting set properly on EC2
instances.

So we have this bug, and we know things used to work. I fired up the
first and last releases of F28 Atomic Host. Both had the problem. I
then went all the way back to the
[first release of F27 Atomic Host](https://lists.projectatomic.io/projectatomic-archives/atomic-devel/2017-November/msg00073.html)
and fired up an AMI from that release. On that release the `MTU` looks
good at `9001`:

```nohighlight
[root@ip-10-0-246-17 ~]# ip addr show eth0 | grep mtu
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
```

I then went all the way to the latest F27 commit of `27.153` (`ddaa675`)
by doing an `rpm-ostree upgrade`. After upgrading I see the non-jumbo
`MTU` value of `1500`:

```nohighlight
[root@ip-10-0-246-17 ~]# ip addr show eth0 | grep mtu
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
```

Where was this regression introduced?

# Bisecting 

I could go through each commit in the entire history to find where
the issue was introduced, but with a little logic we can arrive
at the answer in fewer steps.

The idea here is that the regression was introduced somewhere and
all commits before that point will not have the regression and
all commits after that will have the regression. With a simple
test we can easily check to see if a commit has the regression
or not. The pseudo-code for the bisect logic looks something 
like this: 

```nohighlight
#   grab info on every commit in history 
#   A -> B -> C -> D -> E -> F -> G
#
#   user provided good/bad commits
#   - good (default to first in history: A)
#   - bad (default to current commit: G) 
#   
#   run test script
#   returns 0 for pass and 1 for failure
#
#   known good is A, known bad is G
#   
#   start bisect:
#   deploy D, test --> bad
#   mark D, E, F bad
#
#   deploy B, test --> good
#   mark B good
#
#   deploy C, test --> bad
#
#   Failure introduced in B -> C
```

Luckily, since `OSTree` is like "Git for your OS", and we have a stream
of discrete changes, we can actually automate the bisect testing.

# Automated Bisecting 

For this particular `MTU` regression we are lucky. We have a 
simple pass/fail test that tells us if the problem exists or 
not. If we script it out it looks something like:

```nohighlight
[fedora@ip-10-0-246-17 ~]$ cat /usr/local/bin/test.sh
#!/bin/bash
sleep 20 # Wait some time for the settings to get applied
if ip addr show eth0 | grep "mtu 1500"; then
    echo "Found mtu 1500. Test Fails"
    exit 1
else
    echo "Found mtu != 1500. Test Passes"
    exit 0
fi
```

If we run the test we can see it fails:

```nohighlight
[root@ip-10-0-246-17 ~]# chmod +x /usr/local/bin/test.sh 
[root@ip-10-0-246-17 ~]# /usr/local/bin/test.sh 
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
Found mtu 1500. Test Fails
```

Now we can grab
[rpm-ostree-bisect](https://raw.githubusercontent.com/ostreedev/ostree-releng-scripts/master/rpm-ostree-bisect)
, a python program I wrote to help us do the bisect
testing, and set it up. 

```nohighlight
[root@ip-10-0-246-17 ~]# curl -L https://raw.githubusercontent.com/ostreedev/ostree-releng-scripts/master/rpm-ostree-bisect > /usr/local/bin/rpm-ostree-bisect
[root@ip-10-0-246-17 ~]# chmod +x /usr/local/bin/rpm-ostree-bisect 
[root@ip-10-0-246-17 ~]# rpm-ostree-bisect --testscript /usr/local/bin/test.sh 
Using data file at: /var/lib/rpm-ostree-bisect.json
Created symlink /etc/systemd/system/multi-user.target.wants/rpm-ostree-bisect.service → /etc/systemd/system/rpm-ostree-bisect.service.
[root@ip-10-0-246-17 ~]# 
[root@ip-10-0-246-17 ~]# reboot 
```

We passed it the path to the executable test. The program
assumes that the current commit is a bad commit and it will
assume that the oldest commit is good. If you'd like you can
explicitly set the known good and known bad commits with
`--good` and `--bad` arguments.

A few more things happened here as well. Since we are going
to be deploying different versions of the OS and rebooting
we'll need to store some state and leverage a startup script
to resume the bisection. `rpm-ostree-bisect` created a systemd
service to aid in the bisection:

```nohighlight
[fedora@ip-10-0-246-17 ~]$ systemctl cat rpm-ostree-bisect.service | tee
# /etc/systemd/system/rpm-ostree-bisect.service

[Unit]
Description=RPM-OSTree Bisect Testing
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/rpm-ostree-bisect --resume
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
```

It also created a json data file with information about
all the commits in the history of the OSTree:

```nohighlight
[fedora@ip-10-0-246-17 ~]$ head -n 12 /var/lib/rpm-ostree-bisect.json 
{
    "commits_info": {
        "ddaa675df9ea91b0233ef996691f7f7fdf4eb84fccdf21a49f46a84fa0b39355": {
            "version": "27.153",
            "heuristic": "TESTED",
            "status": "BAD"
        },
        "892983cd174980ea35f54e571e828aa4365addf2a0f5acdcda770f7b4b87a3a5": {
            "version": "27.152",
            "heuristic": "ASSUMED",
            "status": "UNKNOWN"
        },
```

The data file keeps information about that `status` of each commit
(`BAD`, `GOOD`, or `UNKNOWN`) and the `heuristic` (`GIVEN`, `TESTED`,
`ASSUMED`) that was used to determine the status. `TESTED` means that
commit was explicitly tested, while `ASSUMED` means that the status
was assumed to be good or bad based on if an earlier or later commit
was good or bad.

Now we can reboot our system and the automated bisect testing will
happen on the system for us. We can monitor it from remote by using
`watch` or an `ssh` for loop. One example is:

```nohighlight
$ watch -n 10 ssh fedora@52.91.195.75 journalctl -b0 -n 30 -u rpm-ostree-bisect
```

After waiting some time the bisect was finished. The last run of 
the `rpm-ostree-bisect` service output the following:

```nohighlight
Starting RPM-OSTree Bisect Testing...
Using data file at: /var/lib/rpm-ostree-bisect.json
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
Found mtu 1500. Test Fails
Last known good commit:
  21e115d93d04f206a874973c91185184c70ba2e7500d5b2619d8c849b6cad3c1 : 27.125
First known bad commit:
  e59f9373145bae36f90571feff24719537827273891c822692d037b05d1ff470 : 27.126
libostree pull from 'fedora-atomic' for fedora/27/x86_64/atomic-host complete
security: GPG: commit http: TLS
non-delta: meta: 306 content: 0
transfer: secs: 28 size: 1.7 MB
ostree diff commit old: 21e115d93d04f206a874973c91185184c70ba2e7500d5b2619d8c849b6cad3c1
ostree diff commit new: e59f9373145bae36f90571feff24719537827273891c822692d037b05d1ff470
Upgraded:
  cockpit-bridge 165-1.fc27 -> 166-1.fc27
  cockpit-docker 165-1.fc27 -> 166-1.fc27
  cockpit-networkmanager 165-1.fc27 -> 166-1.fc27
  cockpit-ostree 165-1.fc27 -> 166-1.fc27
  cockpit-system 165-1.fc27 -> 166-1.fc27
  coreutils 8.27-20.fc27 -> 8.27-21.fc27
  coreutils-common 8.27-20.fc27 -> 8.27-21.fc27
  findutils 1:4.6.0-16.fc27 -> 1:4.6.0-19.fc27
  kernel 4.15.17-300.fc27 -> 4.16.3-200.fc27
  kernel-core 4.15.17-300.fc27 -> 4.16.3-200.fc27
  kernel-modules 4.15.17-300.fc27 -> 4.16.3-200.fc27
  libcgroup 0.41-13.fc27 -> 0.41-17.fc27
  selinux-policy 3.13.1-283.30.fc27 -> 3.13.1-283.32.fc27
  selinux-policy-targeted 3.13.1-283.30.fc27 -> 3.13.1-283.32.fc27
Started RPM-OSTree Bisect Testing.
```

So we can see clearly the regression was introduced in `27.126` and the diff
output shows that in that particular commit several things changed. The most
obvious change that could have caused this regression was the `kernel` going
from `4.15.17` to `4.16.3`. This narrows down the window of changes to look at
when trying to track down the specific bug.

Note: Here you can access the final
      [rpm-ostree-bisect.json](/2018-06-10/rpm-ostree-bisect.json) 
      and the 
      [systemd unit journal log](/2018-06-10/journal.txt) 
      from the run.

# Fin

This automated bisecting can really help us find the causes for regressions
by narrowing down the scope of changes we need to look at when performing an
investigation.

