---
title: "None"
tags: [ "1", "2" ]
date: "2012-02-09"
published: false
---
.. quick audit rules for sanity check
.. ==================================

Most of the time when I really want to figure out what is going on
deep within a piece of software I break out ``strace`` and capture all the
gory detail. Unfortunately it isn't always that easy to manipulate and
run something from the command line but I have found that some simple
uses of the audit daemon can give you great insight without having to
dig too deep.

Example Problem
---------------

I have a script, ``switch.py``, I want to call via a bound key sequence from 
i3 window manager. However, I notice that nothing happens when I press the key 
sequence. Is the script failing or is the script not getting called at
all? ``auditd`` and ``auditctl`` can help us figure this out. 

Using audit
-----------

To take advantage of system auditing the daemon must be up and running::

    # systemctl status auditd.service | grep active
           Active: active (running) since Sun 2015-01-25 13:56:27 EST; 1 day 9h ago

You can then add a watch for read/write/execute/attribute accesses on the file::


    # auditctl -w /home/dustymabe/.i3/switch.py -p rwxa -k 'switchtest'
    # auditctl -l
    -w /home/dustymabe/.i3/switch.py -p rwxa -k switchtest

Notice the usage of the -k option to add a *key* to the rule. This means any events that 
match the rule will be tagged with this key and can be easily found. Any accesses will be 
logged and can be viewed later by using ``ausearch`` and ``aureport``. After putting the 
rules in place in another terminal I accessed the file as a normal user::

    $ pwd
    /home/dustymabe
    $ cat  .i3/switch.py
    ... contents of file ...
    $ ls .i3/switch.py
    .i3/switch.py

Then I was able to use a combination of ``ausearch`` and ``aureport`` to easily see
who accessed the file and how it was accessed::

    # ausearch -k switchtest --raw | aureport --file

    File Report
    ===============================================
    # date time file syscall success exe auid event
    ===============================================
    1. 01/26/15 22:59:26 .i3/switch.py 2 yes /usr/bin/cat 1000 1299
    2. 01/26/15 23:00:19 .i3/switch.py 191 no /usr/bin/ls 1000 1300

Awesome.. So with auditing working now all I have to do is press the key sequence to 
see if my script is getting called?? Turns out it was being called::

    # ausearch -k switchtest --raw | aureport --file

    File Report
    ===============================================
    # date time file syscall success exe auid event
    ===============================================
    1. 01/26/15 22:59:26 .i3/switch.py 2 yes /usr/bin/cat 1000 1299
    2. 01/26/15 23:00:19 .i3/switch.py 191 no /usr/bin/ls 1000 1300
    10. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 59 yes /usr/bin/python2.7 1000 1326
    11. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 89 no /usr/bin/python2.7 1000 1327
    12. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 2 yes /usr/bin/python2.7 1000 1328
    13. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 2 yes /usr/bin/python2.7 1000 1329
    14. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 2 yes /usr/bin/python2.7 1000 1330
    15. 01/26/15 23:38:15 /home/dustymabe/.i3/switch.py 2 yes /usr/bin/python2.7 1000 1331

So that enabled me to concentrate on my script and find the bug that was lurking within :)


| Have fun auditing!
| Dusty
