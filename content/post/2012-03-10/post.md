---
title: "Hard Drive Monitoring and E-mail Alerts Using smartd"
tags:
date: "2012-03-10"
draft: false
---

A while back I set up `mdadm` to monitor my RAID array and send email
alerts to notify me of failures. At the same time I also set up `smartd`
(see [S.M.A.R.T.](http://en.wikipedia.org/wiki/S.M.A.R.T.) ) to monitor
the hard drives themselves and to send me email alerts.\
\
To do this you edit the `/etc/smartd.conf` file. After I was done my
`/etc/smartd.conf` file looked like the following:

```nohighlight
#
# HERE IS A LIST OF DIRECTIVES FOR THIS CONFIGURATION FILE.
# PLEASE SEE THE smartd.conf MAN PAGE FOR DETAILS
#
#   -d TYPE Set the device type: ata, scsi, marvell, removable, 3ware,N, hpt,L/M/N
#   -T TYPE set the tolerance to one of: normal, permissive
#   -o VAL  Enable/disable automatic offline tests (on/off)
#   -S VAL  Enable/disable attribute autosave (on/off)
#   -n MODE No check. MODE is one of: never, sleep, standby, idle
#   -H      Monitor SMART Health Status, report if failed
#   -l TYPE Monitor SMART log.  Type is one of: error, selftest
#   -f      Monitor for failure of any 'Usage' Attributes
#   -m ADD  Send warning email to ADD for -H, -l error, -l selftest, and -f
#   -M TYPE Modify email warning behavior (see man page)
#   -s REGE Start self-test when type/date matches regular expression (see man page)
#   -p      Report changes in 'Prefailure' Normalized Attributes
#   -u      Report changes in 'Usage' Normalized Attributes
#   -t      Equivalent to -p and -u Directives
#   -r ID   Also report Raw values of Attribute ID with -p, -u or -t
#   -R ID   Track changes in Attribute ID Raw value with -p, -u or -t
#   -i ID   Ignore Attribute ID for -f Directive
#   -I ID   Ignore Attribute ID for -p, -u or -t Directive
#   -C ID   Report if Current Pending Sector count non-zero
#   -U ID   Report if Offline Uncorrectable count non-zero
#   -W D,I,C Monitor Temperature D)ifference, I)nformal limit, C)ritical limit
#   -v N,ST Modifies labeling of Attribute N (see man page)
#   -a      Default: equivalent to -H -f -t -l error -l selftest -C 197 -U 198
#   -F TYPE Use firmware bug workaround. Type is one of: none, samsung
#   -P TYPE Drive-specific presets: use, ignore, show, showall
#    #      Comment: text after a hash sign is ignored
#    \      Line continuation character
# Attribute ID is a decimal integer 1 <= ID <= 255
# except for -C and -U, where ID = 0 turns them off.
# All but -d, -m and -M Directives are only implemented for ATA devices
#
# If the test string DEVICESCAN is the first uncommented text
# then smartd will scan for devices /dev/hd[a-l] and /dev/sd[a-z]
DEVICESCAN -o on -H -l error -l selftest -t -m dustymabe@gmail.com -M test
```

\
It is pretty much all comments except for the last line. You can see
from the comments what each option on the last line means. To summarize
I am telling `smartd` to:\
\
*"Monitor the health status as well as the error and selftest logs of
all /dev/hd\[a-l\] and /dev/sd\[a-z\] devices that are discovered to
have SMART capabilities. Report any errors/failures as well as startup
test messages to dustymabe@gmail.com."*\
\
Now just make sure the `smartd` service is configured to run by default
and your disks should be monitored! You can check this by looking to see
if you get an email when `smartd` starts (make sure to check your spam
filter).\
\
Dusty Mabe
