---
title: "Monitor RAID Arrays and Get E-mail Alerts Using mdadm"
tags:
date: "2012-01-29"
draft: false
---
\
In my Desktop computer I use a software
[RAID1](http://en.wikipedia.org/wiki/RAID) to protect against a data
loss due to a hard drive failure. I have two hard drives, each with four
identically sized partitions. Partition 1 on disk A is mirrored with
partition 1 on disk B. Together they create the "multiple-device" device
node `md1` which can then be treated like any block device. Partitions
2, 3, 4 on the disks make up `md2`, `md3`, and `md4` respectively.\
\
You can use [`mdadm`](http://en.wikipedia.org/wiki/Mdadm) to configure a
software raid in Linux. To see the status of the raid you can view the
contents of the `/proc/mdstat` file. For my software raid the contents
of the file should look like:\
\

```nohighlight
media:~ # cat /proc/mdstat
Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md2 : active raid1 sdb2[1] sda2[0]
      4194240 blocks [2/2] [UU]

md4 : active raid1 sdb4[2] sda4[0]
      867607168 blocks [2/2] [UU]

md1 : active raid1 sdb1[1] sda1[0]
      102336 blocks [2/2] [UU]

md3 : active raid1 sdb3[1] sda3[0]
      104857536 blocks [2/2] [UU]

unused devices: <none>
```

\
Note that the components of each raid device are listed as well as the
status of the raid. For `md1` it shows that `sda1` and `sdb1` are
members of the array. It also shows that both sides of the array are
good; indicated by the `[UU]`.\
\
Periodically I check the status of the raid by checking `/proc/mdstat`,
but not nearly often enough. The other day I was surprised to find that
one of the disks in my software raid had failed. The `/proc/mdstat`
showed me this:\
\

```nohighlight
media:~ # cat /proc/mdstat
Personalities : [raid0] [raid1] [raid10] [raid6] [raid5] [raid4]
md2 : active raid1 sda2[0]
      4194240 blocks [2/1] [U_]

md4 : active raid1 sda4[0]
      867607168 blocks [2/1] [U_]

md1 : active raid1 sda1[0]
      102336 blocks [2/1] [U_]

md3 : active raid1 sda3[0]
      104857536 blocks [2/1] [U_]

unused devices: <none>
```

\
Basically, the disk `/dev/sdb` had been removed from the array for some
reason. I know this because `/dev/sdb` is not listed in any of the
arrays and the status of each array is `[U_]`, which means only one side
of the mirror is active.\
\
After combing through `/var/log/messages` a bit I found some errors that
explain:\
\

```nohighlight
kernel: ata3.00: exception Emask 0x0 SAct 0x0 SErr 0x0 action 0x6 frozen
kernel: ata3.00: failed command: FLUSH CACHE EXT
kernel: ata3.00: cmd ea/00:00:00:00:00/00:00:00:00:00/a0 tag 0
kernel:          res 40/00:00:00:4f:c2/00:00:00:00:00/40 Emask 0x4 (timeout)
kernel: ata3.00: status: { DRDY }
kernel: ata3: hard resetting link
kernel: ata3: link is slow to respond, please be patient (ready=0)
kernel: ata3: SRST failed (errno=-16)
kernel: ata3: hard resetting link
kernel: ata3: link is slow to respond, please be patient (ready=0)
kernel: ata3: SRST failed (errno=-16)
kernel: ata3: hard resetting link
kernel: ata3: link is slow to respond, please be patient (ready=0)
kernel: ata3: SRST failed (errno=-16)
kernel: ata3: limiting SATA link speed to 1.5 Gbps
kernel: ata3: hard resetting link
kernel: ata3: SRST failed (errno=-16)
kernel: ata3: reset failed, giving up
kernel: ata3.00: disabled
kernel: ata3.00: device reported invalid CHS sector 0
kernel: ata3: EH complete
kernel: sd 2:0:0:0: [sdb] Unhandled error code
kernel: sd 2:0:0:0: [sdb]  Result: hostbyte=DID_BAD_TARGET driverbyte=DRIVER_OK
kernel: sd 2:0:0:0: [sdb] CDB: Write(10): 2a 00 0d 03 27 80 00 00 08 00
kernel: end_request: I/O error, dev sdb, sector 218310528
kernel: end_request: I/O error, dev sdb, sector 218310528
kernel: md: super_written gets error=-5, uptodate=0
kernel: md/raid1:md3: Disk failure on sdb3, disabling device.
kernel: <1>md/raid1:md3: Operation continuing on 1 devices.
```

\
From the timestamps on the messages (not shown above) I found out that
it had been over a month since this had occured. A failure on the other
disk during this time could have left me with data loss (luckily, I also
backup my important files to an offsite server, but let's pretend I
don't).\
\
I decided at this point that I need a better way to be notified when
things like this happen. It turns out you can configure `mdadm` to
monitor the raid arrays and notify you via email when errors occur. To
achieve this effect I added the following line to the `/etc/mdadm.conf`
file:\
\

```nohighlight
MAILADDR dustymabe@gmail.com
```

\
Now, as long as `mdadm` is configured to run and monitor the arrays (on
SUSE it is the `mdadmd` service), then you will get email alerts when
things go wrong.\
\
To verify your emails are working you can use the following command,
which will send out a test email:\
\

```nohighlight
sudo mdadm --monitor --scan --test -1
```

\
Having the email monitoring will be sure to give you fair warning before
you have a data loss. Make sure you send out the test email and verify
it isn't getting filtered out as spam.\
\
Cheers!\
\
Dusty Mabe
