---
title: "Installing/Starting Systemd Services Using Cloud-Init"
tags:
date: "2015-08-03"
published: true
url: "/2015/08/03/installingstarting-systemd-services-using-cloud-init/"
---

.. Installing/Starting Systemd Services Using Cloud-Init
.. =====================================================


Intro
-----

Using cloud-init_ to bootstrap cloud instances and install custom
sofware/services is common practice today. One thing you often
want to do is install the software, enable it to start on boot, and
then start it so that you don't have to reboot in order to go ahead
and start using it. 

.. _cloud-init: https://launchpad.net/cloud-init


The Problem
-----------

Actually starting a service can be tricky though because when
executing ``cloud-init`` configuration/scripts you are essentially already
within a ``systemd`` unit while you try to start another ``systemd`` unit.

To illustrate this I decided to start a Fedora 22 cloud instance and 
install/start ``docker`` as part of bringup. The instance I started had
the following user-data::

    #cloud-config
    packages:
      - docker
    runcmd:
      - [ systemctl, daemon-reload ]
      - [ systemctl, enable, docker.service ]
      - [ systemctl, start, docker.service ]

After the system came up and some time had passed (takes a minute for the
package to get installed) here is what we are left with::

    [root@f22 ~]# pstree -asp 925
    systemd,1 --switched-root --system --deserialize 21
      `-cloud-init,895 /usr/bin/cloud-init modules --mode=final
          `-runcmd,898 /var/lib/cloud/instance/scripts/runcmd
              `-systemctl,925 start docker.service
    [root@f22 ~]# systemctl status | head -n 5
    ● f22
        State: starting
         Jobs: 5 queued
       Failed: 0 units
        Since: Tue 2015-08-04 00:49:13 UTC; 30min ago

Basically the ``systemctl start docker.service`` command has been started but
is blocking until it finishes. It doesn't ever finish though. As can be seen from
the output above it's been 30 minutes and the system is still *starting* with 5 jobs *queued*. 

I suspect this is because the ``start`` command queues the start of the ``docker``
service which then waits to be scheduled. It doesn't ever get scheduled, though,
because the ``cloud-final.service`` unit needs to complete first.


The Solution
------------

Is there a way to get the desired behavior? There is an option to 
``systemctl`` that will cause it to not block during an operation, but
rather just queue the action and exit. This is the ``--no-block`` option. From the ``systemctl`` man page::

   --no-block
       Do not synchronously wait for the requested operation
       to finish. If this is not specified, the job will be
       verified, enqueued and systemctl will wait until it is
       completed. By passing this argument, it is only
       verified and enqueued.


To test this out I just added ``--no-block`` to the user-data file that was used 
previously::

    #cloud-config
    packages:
      - docker
    runcmd:
      - [ systemctl, daemon-reload ]
      - [ systemctl, enable, docker.service ]
      - [ systemctl, start, --no-block, docker.service ]

And.. After booting the instance we get a running service::

    [root@f22 ~]# systemctl is-active docker
    active

| Cheers!
|
| Dusty
