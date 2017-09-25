---
title: "Hi Planet! - SSH: Disable checking host key against known_hosts file."
tags:
date: "2012-01-09"
published: true
---

Hi Everyone! Since this is my first post it is going to be short and
sweet. :)\
\
I work on a daily basis with Linux Servers that must be installed,
configured, re-installed, configured etc... Over and over, develop and
test. Our primary means of communication with these servers is through
ssh. Every time a server is re-installed it generates a new ssh key and
thus you will always get a "Man in the Middle Attack" warning from SSH
like:\
\

```nohighlight
[root@fedorabook .ssh]# ssh 1.1.1.2
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that the RSA host key has just been changed.
The fingerprint for the RSA key sent by the remote host is
08:50:e8:e4:1b:17:fd:69:08:bf:44:f2:c4:e4:8a:27.
Please contact your system administrator.
Add correct host key in /root/.ssh/known_hosts to get rid of this message.
Offending key in /root/.ssh/known_hosts:1
RSA host key for 1.1.1.2 has changed and you have requested strict checking.
Host key verification failed.
```

\
\
You then have to open the `~/.ssh/known_hosts` file and remove the
offending key.\
\
Since this is quite a mind numbing and time wasting task, I decided to
win back those precious seconds. While perusing the `ssh_config` man
page, I notice in the description of the `StrictHostKeyChecking` option
that:\
\
***"The host keys of known hosts will be verified automatically in all
cases."***\
\
This means that there is virtually no way to make it ignore the fact
that the key has changed. At least there is no "designed" way.\
\
I then started looking at the file that the remote key is checked
against; the `~/.ssh/known_hosts` file.\
\
From what I can tell it is also impossible to disable writing remote
host keys to this file.\
\
So here we are with:\
\

1.  No way to stop writing remote host keys into the known\_hosts file
2.  No way to ignore the fact that the key in the known\_hosts file
    doesn't match the key in the (newly reinstalled) target server.

\
\
What is the solution to this?\
\
Well, since we can't disable writing new keys to the known\_hosts file
and we can't disable checking keys that are in the known\_hosts file,
why don't we just make the known\_hosts file always be empty. Yep,
that's right. Let's just point the known\_hosts file to `/dev/null`.\
\
Turns out you can do this by setting the UserKnownHostsFile option in
the `~/.ssh/config` file.\
\

```nohighlight
UserKnownHostsFile=/dev/null
```

\
\
Voila! Now you will never be bothered by the same message again. It
isn't all fruit and berries though. Now, since your known\_hosts file is
always empty, you will **always** be presented with the following
message **every time** you ssh to any server:\
\

```nohighlight
[root@fedorabook .ssh]# ssh 1.1.1.2
The authenticity of host '1.1.1.2 (1.1.1.2)' can't be established.
RSA key fingerprint is 08:50:e8:e4:1b:17:fd:69:08:bf:44:f2:c4:e4:8a:27.
Are you sure you want to continue connecting (yes/no)?
```

\
\
In other words, you just traded one pain for another. However there is a
solution for this as well :). We can make SSH automatically write new
host keys to the known\_hosts file by setting `StrictHostKeyChecking` to
"no" in the `~/.ssh/config` file.\
\

```nohighlight
StrictHostKeyChecking=no
```

\
\
And now you are smooth sailing to connect away without the impedence of
interactive warning and error messages. Beware, however, that there are
some security implications to performing the modifications that I have
suggested. The web page
[here](http://www.symantec.com/connect/articles/ssh-host-key-protection)
has an overview of SSH security, the different ssh options, and the
implications of each. Of course, it suggests that you shouldn't set
`StrictHostKeyChecking=no` but in my case, working on lab/test machines
without sensitive data on them, I decided to take the risk.\
\
Enjoy!\
\
Dusty Mabe
