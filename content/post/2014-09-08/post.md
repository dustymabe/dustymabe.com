---
title: "Capture Elusive cloud-init Debug Output With journalctl"
tags:
date: "2014-09-08"
draft: false
---

Recently I have been trying to debug some problems with cloud-init in
the alpha versions of cloud images for CentOS 7 and Fedora 21. What I
have found is that it's not so straight forward to figure out how to set
up debug logging.\
\
The defaults (defined in
[/etc/cloud/cloud.cfg.d/05_logging.cfg](/2014-09-08/05_logging.cfg) )
for some reason don't really capture the debug output in
`/var/log/cloud-init.log`. Luckily, though, on `systemd` based systems
we can get most of that output by using `journalctl`. There are several
services releated to cloud-init and if you want to get the output from
all of them you can just use wildcard matching in `journalctl` (freshly
added in
[ea18a4b](http://cgit.freedesktop.org/systemd/systemd/commit/?id=ea18a4b57e2bb94af7b3ecb7abdaec40e9f485f0)
) like so:\
\

```nohighlight
[root@f21test ~]# journalctl --unit cloud-*
...debug...debug...blah...blah
```

\
This worked great in Fedora 21, but in CentOS/RHEL 7 this actually won't
work because wildcard matching is too new. As a result I found another
way to get the same output. It just so happens that the services all use
the same executable (`/usr/bin/cloud-init`) so I was able to use that as
a trigger:\
\

```nohighlight
[root@c7test ~]# journalctl /usr/bin/cloud-init
...debug...debug...blah...blah
```

\
I hope others can find this useful when debugging cloud-init.\
\
Cheers,\
Dusty
