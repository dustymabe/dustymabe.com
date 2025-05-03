---
title: "Docker: Copy Into A Container Volume"
tags:
date: "2014-08-27"
draft: false
---

I need to copy a few files into my docker container.. Should be easy
right? Turns out it's not so trivial. In Docker 1.0.0 and earlier the
`docker cp` command can be used to copy files from a container to the
host, but not the other way around...\
\
Most of the time you can work around this by using an `ADD` statement in
the Dockerfile but I often need to populate some data within data-only
volume containers before I start other containers that use the data. To
achieve copying data into the volume you can simply use `tar` and pipe
the contents into the volume within a new container like so:\

```nohighlight
[root@localhost ~]# docker run -d -i -t -v /volumes/wpdata --name wpdata mybusybox sh
416ea2a877267f566ef8b054a836e8b6b2550b347143c4fe8ed2616e11140226
[root@localhost ~]# 
[root@localhost ~]# tar -c files/ | docker run -i --rm -w /volumes/wpdata/ --volumes-from wpdata mybusybox tar -xv
files/
files/file8.txt
files/file9.txt
files/file4.txt
files/file7.txt
files/file1.txt
files/file6.txt
files/file2.txt
files/file5.txt
files/file10.txt
files/file3.txt
```

\
So.. In the example I created a new data-only volume container named
*wpdata* and then ran `tar` to pipe the contents of a directory to a new
container that also used the same volumes as the original container. Not
so tough, but not as easy as `docker cp`. I think `docker cp` should
have this functionality sometime in the future ( issue tracker
[here](https://github.com/docker/docker/pull/6580) ).\
\
Enjoy\
\
Dusty
