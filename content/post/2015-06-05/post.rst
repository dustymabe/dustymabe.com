---
title: "None"
tags: [ "1", "2" ]
date: "2012-02-09"
published: false
---

.. Fedora 22 Now Swimming in DigitalOcean
.. ======================================

*cross posted from this_ fedora magazine post*

.. _this: http://fedoramagazine.org/fedora-22-now-swimming-digitalocean/

DigitalOcean is a cloud provider that provides a
`one-click deployment of a Fedora Cloud instance`_ to an all-SSD
server in under a minute. 
After some quick work by the DigitalOcean_ and `Fedora Cloud`_ teams
we are pleased to announce that you can now make it rain Fedora 22
droplets! 

.. _one-click deployment of a Fedora Cloud instance: https://www.digitalocean.com/features/linux-distribution/fedora/
.. _DigitalOcean: https://www.digitalocean.com/company/about/
.. _Fedora Cloud: https://fedoraproject.org/wiki/Cloud/Governance

One significant change over previous Fedora droplets is that this is 
the first release to have support for managing your kernel internally.
Meaning if you ``dnf update kernel-core`` and reboot then you'll
actually be running the kernel you updated to. Win!

Here are a couple more tips for Fedora 22 Droplets:

- Like with other DigitalOcean images, you will log in with your ssh
  key as **root** rather than the typical **fedora** user that you may
  be familiar with when logging in to a Fedora cloud image.

- Similar to Fedora 21, Fedora 22 also has SELinux enabled by default.

- Fedora 22 should be available in all the newest datacenters in each
  region, but some legacy datacenters aren't supported. If you have a
  problem you think is Fedora specific then drop us an email at
  cloud@lists.fedoraproject.org, ping us in **#fedora-cloud** on
  freenode, or visit the Fedora cloud trac_ to see if it is already 
  being worked on. 

.. _trac: https://fedorahosted.org/cloud/report/1

Visit the DigitalOcean Fedora landing page_ and spin one up today!

.. _page: https://www.digitalocean.com/features/linux-distribution/fedora/

| Happy Developing!
| Dusty
