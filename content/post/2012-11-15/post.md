---
title: "Create A Disk Image Without Enough Free Space"
tags:
date: "2012-11-15"
published: true
---

\
Recently I purchased a new laptop. Typically my first move is to ditch
Windows or Mac (yes I've done both) and install Linux. This time, just
in case I ever want to completely restore the system (recovery partition
and all), I decided to make a disk image of the entire hard drive.\
\
Being that the capacity of the hard drive is close to 500 GB it actually
turned out that I didn't have enough free space to store the entire
image. However, since it was a brand new computer I knew there was
plenty of zeroes on the disk and thus plenty of opportunity to reduce
the actual size of the disk image by converting those zeroes into holes
in a [sparse file](http://en.wikipedia.org/wiki/Sparse_file) .\
\
Now usually when creating a disk image I would just use `dd`, but `dd`
doesn't have any options that are sparse file aware. Luckily I was able
to find a
[page](http://serverfault.com/questions/93667/create-image-from-hard-disk-without-free-space-linux)
that addressed my particular predicament.\
\
The secret sauce here is the `--sparse=always` option of `cp`. By piping
the output of `dd` to `cp`, I could then copy my disk image! The next
step was to fire up a live cd, connect an external hard drive and run
the following command to create the disk image:\

```nohighlight
dd if=/dev/sda | cp --sparse=always /dev/stdin lenovo.img
```

Just to be careful I decided to md5sum both the disk image and the block
device to make sure they had the same sums:\

```nohighlight
dustymabe@media: >sudo md5sum lenovo.img
fbd07bc0fc46622e0bfc1ac2b44915e5  lenovo.img

ubuntu@ubuntu:~$ sudo md5sum /dev/sda 
fbd07bc0fc46622e0bfc1ac2b44915e5  /dev/sda
```

Success! So how much space did I actually save by make the image a
sparse image? We can see by using the `du` command:

```nohighlight
dustymabe@media: mnt>du -sh lenovo.img
38G     lenovo.img
dustymabe@media: mnt>du -sh --apparent-size lenovo.img
466G    lenovo.img
```

This means that the disk image only actually took 38 GB of disk space
but would have taken 466 GB if I had not made it a sparse disk image...
Mission accomplished!!\
\
Until next time...\
\
Dusty\
\
References:\
<http://serverfault.com/questions/93667/create-image-from-hard-disk-without-free-space-linux>
