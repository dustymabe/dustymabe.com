---
title: "Creating Your Own Minimal Docker Image in Fedora"
tags:
date: "2014-07-07"
draft: false
---

Sometimes it can be useful to have a docker image with just the bare
essentials. Maybe you want to have a container with just enough to run
your app or you are using something like [data volume
containers](https://docs.docker.com/userguide/dockervolumes/#creating-and-mounting-a-data-volume-container)
and want just enough to browse the filesystem. Either way you can create
your own minimalist `busybox` image on Fedora with a pretty simple
script.\
\
The script below was inspired a little from Marek Goldmann's
[post](http://goldmann.pl/blog/2014/03/06/creating-a-minimal-wildfly-docker-image/)
about creating a minimal image for wildfly and a little from the busybox
[website](http://www.busybox.net/FAQ.html#getting_started) .\
\

```nohighlight
# cd to a temporary directory
tmpdir=$(mktemp -d)
pushd $tmpdir

# Get and extract busybox 
yumdownloader busybox 
rpm2cpio busybox*rpm | cpio -imd
rm -f busybox*rpm

# Create symbolic links back to busybox
for i in $(./sbin/busybox --list);do
    ln -s /sbin/busybox ./sbin/$i
done

# Create container
tar -c . | docker import - mybusybox

# Go back to old pwd
popd
```

\
After running the script there is a new image on your system with the
***mybusybox*** tag. You can run it and take a look around like so:\

```nohighlight
[root@localhost ~]# docker images mybusybox
REPOSITORY  TAG      IMAGE ID        CREATED          VIRTUAL SIZE
mybusybox   latest   f526db9e0d80    12 minutes ago   1.309 MB
[root@localhost ~]#
[root@localhost ~]# docker run -i -t mybusybox /sbin/busybox sh
# ls -l /sbin/ls
lrwxrwxrwx   1 0    0    13 Jul  8 02:15 /sbin/ls -> /sbin/busybox
# 
# ls /
dev   etc   proc  sbin  sys   usr
# 
# df -kh .
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/docker-253:0-394094-addac9507205082fbd49c8f45bbd0316fd6b3efbb373bb1d717a3ccf44b8a97e
                          9.7G     23.8M      9.2G   0% /
```

\
Enjoy!\
\
Dusty
