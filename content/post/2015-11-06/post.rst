---
title: "Fedora 23: In the Ocean Again"
tags:
date: "2015-11-06"
published: true
---

.. Fedora 23: In the Ocean Again
.. =============================

*Cross posted with this_ fedora magazine post*

.. _this: https://fedoramagazine.org/fedora-23-in-the-ocean-again/

This week was the release week for Fedora 23, and the Fedora Project
has again worked together with the
DigitalOcean_ team to make Fedora 23 available in their service. If
you're not familiar with DigitalOcean already, it is a dead simple 
cloud hosting platform which is great for developers.

.. _DigitalOcean: https://www.digitalocean.com/

Using Fedora on DigitalOcean 
----------------------------

There are a couple of things to note if you are planning on using
Fedora on DigitalOcean services and machines.

- Like with other DigitalOcean images, you will 
  **log in with your ssh key as root**, rather than the typical fedora 
  user that you may be familiar with when logging in to a Fedora cloud image.
- Similar to Fedora 21 and Fedora 22, Fedora 23 also has 
  **SELinux enabled by default**.
- In DigitalOcean images there is **no firewall on by default**, and there
  is **no cloud provided firewall solution**. It is highly recommended that
  you secure your system after you log in.
- Fedora 23 should be available in 
  **all the newest datacenters in each region**, but some legacy 
  datacenters aren't supported. 
- If you have a
  problem you think is Fedora specific then drop us an email at
  cloud@lists.fedoraproject.org, ping us in #fedora-cloud on freenode,
  or visit the Fedora cloud trac_ to see if it is already being
  worked on.

.. _trac: https://fedorahosted.org/cloud/report/1

Visit the DigitalOcean `Fedora landing page`_ and spin one up today!

.. _Fedora landing page: https://www.digitalocean.com/features/linux-distribution/fedora/


| Happy Developing!
| Dusty
