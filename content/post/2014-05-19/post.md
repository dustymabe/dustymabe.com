---
title: "TermRecord: Terminal Screencast in a Self-Contained HTML File"
tags:
date: "2014-05-19"
published: true
---

#### *Introduction*

\
Some time ago I wrote a few posts (
[1,](/2012/01/11/create-a-screencast-of-a-terminal-session-using-scriptreplay/)
[2](/2012/04/15/terminal-screencast-revisit-log-output-from-a-multiplexed-terminal/)
) on how to use `script` to record a terminal session and then
`scriptreplay` to play it back. This functionality can be very useful by
enabling you the power to *show* others what happens when you do
***insert anything here***.\
\
I have been happy with this solution for a while until one day [Wolfgang
Richter](http://www.cs.cmu.edu/~worichte/) commented on my original
[post](/2012/01/11/create-a-screencast-of-a-terminal-session-using-scriptreplay/)
and shared a project he has been working on known as
[TermRecord.](https://github.com/theonewolf/TermRecord)\
\
I gave it a spin and have been using it quite a bit. Sharing a terminal
recording now becomes much easier as you can simply email the .html file
or you can host it yourself and share links. As long the people you are
sharing with have a browser then they can watch the playback. Thus, it
is not tied to a system with a particular piece of software and clicking
a link to view is very easy to do :)

#### *Basics of TermRecord*

\
Before anything else we need to install `TermRecord`. Currently
[TermRecord](https://pypi.python.org/pypi/TermRecord) is available in
the [python package index](http://pypi.python.org/pypi/) (hopefully will
be packaged in some major distributions soon) and can be installed using
`pip`.\

```nohighlight
[root@localhost ~]# pip install TermRecord
Downloading/unpacking TermRecord
  Downloading TermRecord-1.1.3.tar.gz (49kB): 49kB downloaded
  Running setup.py egg_info for package TermRecord
...
...
Successfully installed TermRecord Jinja2 markupsafe
Cleaning up...
```

Now you can make a self-contained html file for sharing in a couple of
ways.\
\
First, you can use TermRecord to convert already existing timing and log
files that were created using the `script` command by specifying them as
inputs to `TermRecord`:\

```nohighlight
[root@localhost ~]# TermRecord -o screencast.html -t screencast.timing -s screencast.log
```

\
The other option is to create a new recording using `TermRecord` like
so:\

```nohighlight
[root@localhost ~]# TermRecord -o screencast.html 
Script started, file is /tmp/tmp5I4SYq
[root@localhost ~]# 
[root@localhost ~]# #This is a screencast.
[root@localhost ~]# exit
exit
Script done, file is /tmp/tmp5I4SYq
```

\
And.. Done. Now you can email or share the html file any way you like.
If you would like to see some examples of terminal recordings you can
check out the [TermRecord github
page](https://github.com/theonewolf/TermRecord) or
[here](/2014-05-10/screencast.html) is one from my previous post on
wordpress/docker.\
\
Cheers,\
Dusty
