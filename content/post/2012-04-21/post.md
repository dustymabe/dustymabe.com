---
title: "Send Magic SysRq to a KVM guest using virsh"
tags:
date: "2012-04-21"
published: true
---

When a linux computer is "hung" or "frozen" you can use a [Magic
SysRq](http://en.wikipedia.org/wiki/Magic_SysRq_key) key sequence to
send various low level requests to the kernel in order to try to recover
from or investigate the problem. This is extremely useful when
troubleshooting server lockups, but until recently
[libvirt](http://en.wikipedia.org/wiki/Libvirt) did not expose this
functionality for
[KVM](http://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine)
guests.\
\
In v0.9.3 (and newer) of libvirt you can send a Magic SysRq sequence to
a guest by utilizing the `send-key` subcommand provided by `virsh`. In
other words, sending the 'h' Magic SysRq command is as simple as:\
\

```nohighlight
dustymabe@media: ~>virsh send-key guest1 KEY_LEFTALT KEY_SYSRQ KEY_H
```

\
After executing the command a help message will be printed to the
console of the guest known as **guest1**. Any other character can be sent
as well by substituting `KEY_H` with `KEY_X`, where `X` is the character.\
\
Happy Investigating!\
\
Dusty
