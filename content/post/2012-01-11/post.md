---
title: "Create a screencast of a terminal session using scriptreplay."
tags:
date: "2012-01-11"
published: true
---

\
I recently ran into an issue where I needed to demo a project without
actually being present for the demo. I thought about recording (into
some video format) a screencast of my terminal window and then having my
audience play it at the time of the demo. This would have worked just
fine, but, as I was browsing the internet searching for exactly how to
record a screencast of this nature, I ran across a [blog
post](http://linux.byexamples.com/archives/279/record-the-terminal-session-and-replay-later/)
talking about how to play back terminal sessions using the output of the
` script` program. This piqued my interest for several reasons:

1.  I have used script many times to log results of tests.
2.  This method of recording a shell session is much more efficient than
    recording it into video because it only stores the actual text of
    the output as well as some timing information.

\
\
In order to "record" using script you store the terminal output and the
timing information to two different files using a command like the
following:\
\

```nohighlight
script -t 2> screencast.timing screencast.log
```

\
\
The `-t` in the command causes script to output timing data to standard
error. The `2> screencast.timing` causes standard error to be
redirected to the file **screencast.timing**. The **screencast.log**
file will hold everything printed on the terminal during the course of
the screencast session.\
\
After running the command, execute a few programs (`ls`,
`echo "Hi Planet"`, etc...) and then type `exit` to end the session.\
\
Now the screencast is stored in the two files. You can play back the
screencast using:\
\

```nohighlight
scriptreplay screencast.timing screencast.log
```

\
\
And Voila. As long as your target audience has a box with
script/scriptreplay installed then they can view your screencast!\
\
I have included a [**screencast.timing**](/2012-01-11/screencast.timing)
and a [**screencast.log**](/2012-01-11/screencast.log) file you can
download and use with `scriptreplay` if you would like to demo this out.
The files combined are under 5K in size for a 1 minute 40 second
screencast, however I think the actual size of the files depends more on
how much data was output rather than the length of the screencast.\
\
Even better than using my screencast, create one yourself!\
\
Enjoy!
