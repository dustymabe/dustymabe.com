---
title: "Exchanging SSH keys using ssh-copy-id"
tags:
date: "2012-08-18"
draft: false
---

It is common practice among Linux users to exchange ssh keys between
machines so that you can ssh between them without having to
authenticate. The manual process for doing this involves taking the
public key of the local host (`~/.ssh/id_rsa.pub` or
`~/.ssh/id_dsa.pub`) and appending it to the `~/.ssh/authorized_keys`
file of the remote host you wish to log in without a password.\
\
This process is simple, but requires a few different steps. Luckily,
openssh includes a nifty little shell script that will take care of all
of the manual steps for you. This script is called `ssh-copy-id` and
should be available on your Linux distro as long as you are using the
openssh client.\
\
In order to use it all you need to do is provide a username and a remote
host to log in to. It will then copy your key to the authorized\_keys
file of the remote host and from then on you should be able to log in
without authenticating. This is illustrated below:\
\

```nohighlight
[root@F17 ~]# ssh-copy-id root@192.168.122.1
The authenticity of host '192.168.122.1 (192.168.122.1)' can't be established.
RSA key fingerprint is 62:e7:6e:18:b8:29:00:2d:f7:e4:5b:ca:81:76:b3:d9.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.122.1' (RSA) to the list of known hosts.
root@192.168.122.1's password:
Now try logging into the machine, with "ssh 'root@192.168.122.1'", and check in:

~/.ssh/authorized_keys

to make sure we haven't added extra keys that you weren't expecting.

[root@F17 ~]#
[root@F17 ~]#
[root@F17 ~]#
[root@F17 ~]# ssh root@192.168.122.1
[root@media ~]#
[root@media ~]#
```

\
As you can see no password was needed after exchanging the key.\
\
**NOTE:** `ssh-copy-id` may give you the following error if no ssh keys
have been generated for the system:\
\

```nohighlight
[root@F17 ~]# ssh-copy-id root@192.168.122.1
/bin/ssh-copy-id: ERROR: No identities found
```

\
If that happens then you need to use `ssh-keygen` to generate keys. You
can do this non-interactively by using
`ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa`. Alternatively you can just
run `ssh-keygen` with no options and answer questions as they are
presented.\
\
Until next time,\
Dusty
