---
title: "Recover Space By Finding Deleted Files That Are Still Held Open."
tags:
date: "2012-01-22"
published: true
---

\
The other day I was trying to clean out some space on an almost full
filesystem that I use to hold some video files. The output from ` df`
looked like:\
\

```nohighlight
media:~ # df -kh /docs/videos/
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/vgvolume-videos 5.0G  4.2G  526M  90% /docs/videos
```

\
I then found the largest file I wanted to delete (a 700M avi video I had
recently watched), and removed it. `df` should now report that I freed
up some space right? NOPE!\
\

```nohighlight
media:~ # df -kh /docs/videos/
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/vgvolume-videos 5.0G  4.2G  526M  90% /docs/videos
```

\
Why wasn't I able to recover the space on the filesystem? At first I
didn't know. I then decided to unmount and remount the filesystem to see
if the changes would take effect. During this process, I found out that
I couldn't unmont the fs because the device was busy:\
\

```nohighlight
media:~ # umount /docs/videos/
umount: /docs/videos: device is busy.
    (In some cases useful info about processes that use
     the device is found by lsof(8) or fuser(1))
```

\
Ahh, so a program still has some files open on the fs. ` lsof` lets us
find out what files.\
\

```nohighlight
media:~ # lsof /docs/videos/
COMMAND     PID      USER   FD   TYPE DEVICE  SIZE/OFF NODE NAME
bash      10889 dustymabe  cwd    DIR  253,6      4096    2 /docs/videos
vlc       11244 dustymabe  cwd    DIR  253,6      4096    2 /docs/videos
vlc       11244 dustymabe   11r   REG  253,6 732297098   14 /docs/videos/video1.avi (deleted)
xdg-scree 11281 dustymabe  cwd    DIR  253,6      4096    2 /docs/videos
xprop     11285 dustymabe  cwd    DIR  253,6      4096    2 /docs/videos
```

\
So `lsof` shows us what files are open but it also let me us know
something else key to my investigation. The file I had deleted was
actually still being held open by VLC media player (I had recently been
watching the video and vlc was still up and paused in the middle of
playback). ` lsof` let us know that the file had been deleted as well.
After closing vlc the space was then released back to the filesystem :)\

```nohighlight
media:~ # df -kh /docs/videos/
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/vgvolume-videos 5.0G  3.5G  1.2G  75% /docs/videos
```

\
As a side note it is worth mentioning that all files that have been
deleted but are still be held open by running processes are listed as
"(deleted)" when performing an ` ls -l` in the proc file system. For
example, to find the file that I deleted that was still being held open
by vlc then I would use ` ls -lR /proc/11244/fd/ | grep deleted`. An
example of the output is shown below:\
\

```nohighlight
media:~ # ls -l /proc/11244/fd/ | grep deleted
lr-x------ 1 dustymabe users 64 Jan 22 21:58 11 -> /docs/videos/video1.avi (deleted)
```

\
\
Cheers!
